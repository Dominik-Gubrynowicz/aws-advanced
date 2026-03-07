import os
import json
import urllib.parse
import boto3
from datetime import datetime
import uuid

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
mediaconvert = boto3.client('mediaconvert')

CATALOG_TABLE = os.environ['CATALOG_TABLE']
OUTPUT_BUCKET = os.environ['OUTPUT_BUCKET']
MEDIACONVERT_ROLE = os.environ['MEDIACONVERT_ROLE']
MEDIACONVERT_ENDPOINT = os.environ.get('MEDIACONVERT_ENDPOINT') # Optional, if set
JOB_TEMPLATE_NAME = os.environ.get('JOB_TEMPLATE_NAME') # Optional, if using predefined template

if MEDIACONVERT_ENDPOINT:
    mediaconvert = boto3.client('mediaconvert', endpoint_url=MEDIACONVERT_ENDPOINT)

table = dynamodb.Table(CATALOG_TABLE)

def handler(event, context):
    try:
        if not MEDIACONVERT_ENDPOINT:
            # Dynamically fetch endpoint if not configured
            endpoints = mediaconvert.describe_endpoints()
            mc_client = boto3.client('mediaconvert', endpoint_url=endpoints['Endpoints'][0]['Url'])
        else:
            mc_client = mediaconvert

        for record in event['Records']:
            source_bucket = record['s3']['bucket']['name']
            source_key = urllib.parse.unquote_plus(record['s3']['object']['key'])
            
            # Simple validation to avoid processing non-media files
            if not source_key.lower().endswith(('.mp4', '.mov', '.avi', '.mkv', '.mpg', '.mpeg', '.mxf')):
                print(f"Skipping non-media object: {source_key}")
                continue

            video_id = str(uuid.uuid4())
            output_prefix = f"outputs/{video_id}/"
            
            input_path = f"s3://{source_bucket}/{source_key}"
            output_path = f"s3://{OUTPUT_BUCKET}/{output_prefix}"
            
            # Record in DynamoDB as reading
            created_at = datetime.utcnow().isoformat() + 'Z'
            
            print(f"Submitting job for {source_key} with video_id {video_id}")
            
            job_settings = {
                "Inputs": [
                    {
                        "FileInput": input_path,
                        "AudioSelectors": {
                            "Audio Selector 1": {
                                "DefaultSelection": "DEFAULT"
                            }
                        },
                        "VideoSelector": {},
                        "TimecodeSource": "ZEROBASED"
                    }
                ],
                "OutputGroups": [
                    {
                        "Name": "Apple HLS",
                        "OutputGroupSettings": {
                            "Type": "HLS_GROUP_SETTINGS",
                            "HlsGroupSettings": {
                                "SegmentLength": 10,
                                "Destination": output_path + "hls/",
                                "MinSegmentLength": 0
                            }
                        },
                        "Outputs": [
                            {
                                "NameModifier": "_1",
                                "VideoDescription": {
                                    "CodecSettings": {
                                        "Codec": "H_264",
                                        "H264Settings": {
                                            "MaxBitrate": 5000000,
                                            "RateControlMode": "QVBR",
                                            "SceneChangeDetect": "TRANSITION_DETECTION"
                                        }
                                    },
                                    "Width": 1920,
                                    "Height": 1080
                                },
                                "AudioDescriptions": [
                                    {
                                        "CodecSettings": {
                                            "Codec": "AAC",
                                            "AacSettings": {
                                                "Bitrate": 96000,
                                                "CodingMode": "CODING_MODE_2_0",
                                                "SampleRate": 48000
                                            }
                                        }
                                    }
                                ],
                                "ContainerSettings": {
                                    "Container": "M3U8",
                                    "M3u8Settings": {}
                                }
                            }
                        ]
                    }
                ]
            }

            job_args = {
                "Role": MEDIACONVERT_ROLE,
                "Settings": job_settings,
                "UserMetadata": {
                    "videoId": video_id
                }
            }

            if JOB_TEMPLATE_NAME:
                # If we have a named template, use it instead of generating inline settings
                job_args = {
                    "Role": MEDIACONVERT_ROLE,
                    "JobTemplate": JOB_TEMPLATE_NAME,
                    "Settings": {
                        "Inputs": [
                            {
                                "FileInput": input_path
                            }
                        ]
                    },
                    "UserMetadata": {
                        "videoId": video_id
                    }
                }
                # To set output destination when using JobTemplate, you can pass it via Settings > OutputGroups but often requires deeper merge
                pass
            
            response = mc_client.create_job(**job_args)
            job_id = response['Job']['Id']
            
            # Save to catalog
            table.put_item(
                Item={
                    'video_id': video_id,
                    'title': source_key.split('/')[-1],
                    'source_key': source_key,
                    'status': 'processing',
                    'created_at': created_at,
                    'updated_at': created_at,
                    'job_id': job_id,
                    'output_prefix': output_prefix
                }
            )
            print(f"Job {job_id} created for video {video_id}")
            
    except Exception as e:
        print(f"Error processing input: {e}")
        raise e
