import os
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Union
import boto3
from botocore.exceptions import ClientError, EndpointConnectionError
from dotenv import load_dotenv
import uvicorn

load_dotenv()
app = FastAPI()

def get_s3_config():
    return {
        "endpoint": os.getenv("S3_ENDPOINT"),
        "region": os.getenv("S3_REGION", "us-east-1"),
        "access_key": os.getenv("S3_ACCESS_KEY"),
        "secret_key": os.getenv("S3_SECRET_KEY"),
        "bucket_name": os.getenv("S3_BUCKET_NAME")
    }

def create_s3_client(config):
    kwargs = {
        'aws_access_key_id': config['access_key'],
        'aws_secret_access_key': config['secret_key'],
    }
    
    if config['endpoint']:
        kwargs['endpoint_url'] = config['endpoint']
    else:
        kwargs['region_name'] = config['region']
    
    return boto3.client('s3', **kwargs)

class S3Client:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client is None:
            config = get_s3_config()
            cls._client = create_s3_client(config)
        return cls._client

def handle_client_error(e):
    error_code = e.response['Error']['Code']
    if error_code == 'PermanentRedirect':
        redirect_region = e.response['Error']['Region']
        S3Client._client = create_s3_client(get_s3_config(), redirect_region)
        return True
    else:
        raise HTTPException(status_code=500, detail=f"Error listing objects: {str(e)}")

def normalize_path(path: str) -> str:
    return path.rstrip('list-bucket-content/') + '/' if path else ""

def list_objects(prefix: str = "") -> List[str]:
    s3_client = S3Client.get_client()
    try:
        contents = set()
        paginator = s3_client.get_paginator('list_objects_v2')
        page_iterator = paginator.paginate(Bucket=get_s3_config()['bucket_name'], Prefix=prefix, Delimiter='/')

        for page in page_iterator:
            if 'CommonPrefixes' in page:
                contents.update(p['Prefix'].rstrip('/').split('/')[-1] for p in page['CommonPrefixes'])
            
            if 'Contents' in page:
                contents.update(obj['Key'].split('/')[-1] for obj in page['Contents'] 
                                if obj['Key'] != prefix and obj['Key'].count('/') == prefix.count('/'))
        if prefix and not contents:
            return None
        return sorted(list(contents))

    except ClientError as e:
        if handle_client_error(e):
            return list_objects(prefix)
    except EndpointConnectionError:
        raise HTTPException(status_code=500, detail="Unable to connect to the S3 endpoint. Please check your S3_ENDPOINT configuration.")

@app.get("/")
async def list_endpoints():
    openapi_schema = app.openapi()
    endpoints = [route for route in openapi_schema['paths']]
    return JSONResponse(content={"endpoints": endpoints})

@app.get("/health")
async def health_check():
    return JSONResponse(content={"status": "healthy"})

@app.get("/list-bucket-content")
@app.get("/list-bucket-content/{path:path}")
async def list_bucket_content(path: str = ""):
    normalized_path = normalize_path(path)
    content = list_objects(normalized_path)
    
    if content is None:
        return JSONResponse(
            status_code=404,
            content={"error": f"Path '{path}' does not exist in the bucket"}
        )
    
    return JSONResponse(content={"content": content})

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
