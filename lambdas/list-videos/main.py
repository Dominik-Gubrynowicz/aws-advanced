import os
import json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
CATALOG_TABLE = os.environ['CATALOG_TABLE']
table = dynamodb.Table(CATALOG_TABLE)

def handler(event, context):
    try:
        # Use the GSI "StatusCreatedAtIndex" to efficiently query completed/ready videos,
        # or we could scan if traffic is low. Let's query for status='ready'.
        
        response = table.query(
            IndexName='StatusCreatedAtIndex',
            KeyConditionExpression=Key('status').eq('ready'),
            ScanIndexForward=False # Sort by created_at descending (newest first)
        )
        
        items = response.get('Items', [])
        
        # We can also fetch 'processing' items if we want to show encoding state
        resp_processing = table.query(
            IndexName='StatusCreatedAtIndex',
            KeyConditionExpression=Key('status').eq('processing'),
            ScanIndexForward=False
        )
        items.extend(resp_processing.get('Items', []))
        
        # Clean up response for frontend (remove internal fields like job_id if we want)
        videos = []
        for item in items:
            videos.append({
                'id': item.get('video_id'),
                'title': item.get('title'),
                'status': item.get('status'),
                'manifest_url': item.get('manifest_url'),
                'created_at': item.get('created_at'),
                'thumbnail_url': item.get('thumbnail_url')
            })

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*' # CORS
            },
            'body': json.dumps(videos)
        }
    except Exception as e:
        print(f"Error fetching videos: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }
