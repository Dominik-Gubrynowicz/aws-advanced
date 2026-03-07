import os
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
CATALOG_TABLE = os.environ['CATALOG_TABLE']
table = dynamodb.Table(CATALOG_TABLE)

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    try:
        detail = event.get('detail', {})
        status = detail.get('status')
        job_id = detail.get('jobId')
        user_metadata = detail.get('userMetadata', {})
        video_id = user_metadata.get('videoId')
        
        if not video_id:
            print(f"No video_id found in userMetadata for job {job_id}")
            # Try to query by job_id if video_id missing (would require a GSI on job_id)
            return

        updated_at = datetime.utcnow().isoformat() + 'Z'
        
        if status == 'COMPLETE':
            # Construct the manifest URL
            # The output group is set up in the template to write to output_prefix + 'hls/'
            # The playlist is typically output.m3u8, but MediaConvert uses the output modifier or base name.
            # Assuming our trigger used Destination without a filename, it appends the filename from the template.
            # We'll construct a general URL if Cloudfront domain is provided.
            
            # Fetch current item to get output_prefix
            response = table.get_item(Key={'video_id': video_id})
            item = response.get('Item')
            
            if not item:
                print(f"Video {video_id} not found in catalog")
                return
            
            output_prefix = item.get('output_prefix', f"outputs/{video_id}/")
            
            # HLS manifest is typically stored at {output_prefix}hls/...
            # To be exact, one should parse the EventBridge payload for output paths:
            output_groups = detail.get('outputGroupDetails', [])
            manifest_path = ""
            for og in output_groups:
                if 'playlistFilePaths' in og and len(og['playlistFilePaths']) > 0:
                    s3_path = og['playlistFilePaths'][0] # e.g. s3://bucket/outputs/123/hls/movie.m3u8
                    path_parts = s3_path.replace("s3://", "").split("/")
                    # Remove bucket part
                    object_key = "/".join(path_parts[1:])
                    manifest_path = f"/{object_key}"
                    break

            table.update_item(
                Key={'video_id': video_id},
                UpdateExpression="SET #s = :status, updated_at = :updated_at, manifest_url = :manifest_url",
                ExpressionAttributeNames={'#s': 'status'},
                ExpressionAttributeValues={
                    ':status': 'ready',
                    ':updated_at': updated_at,
                    ':manifest_url': manifest_path
                }
            )
            print(f"Updated video {video_id} to status=ready")
            
        elif status in ['ERROR', 'CANCELED']:
            error_message = detail.get('errorMessage', 'Unknown error')
            table.update_item(
                Key={'video_id': video_id},
                UpdateExpression="SET #s = :status, updated_at = :updated_at, error_message = :err",
                ExpressionAttributeNames={'#s': 'status'},
                ExpressionAttributeValues={
                    ':status': 'failed',
                    ':updated_at': updated_at,
                    ':err': error_message
                }
            )
            print(f"Updated video {video_id} to status=failed due to {error_message}")
            
    except Exception as e:
        print(f"Error processing job completion: {e}")
        raise e
