import os
import pytest
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock
from app.app import app, get_s3_config, create_s3_client, S3Client, list_objects

client = TestClient(app)

@pytest.fixture(autouse=True)
def set_env_vars():
    os.environ["S3_ENDPOINT"] = "http://localhost:4566"
    os.environ["S3_REGION"] = "us-east-1"
    os.environ["S3_ACCESS_KEY"] = "test_access_key"
    os.environ["S3_SECRET_KEY"] = "test_secret_key"
    os.environ["S3_BUCKET_NAME"] = "test_bucket"
    yield
    os.environ.pop("S3_ENDPOINT")
    os.environ.pop("S3_REGION")
    os.environ.pop("S3_ACCESS_KEY")
    os.environ.pop("S3_SECRET_KEY")
    os.environ.pop("S3_BUCKET_NAME")

def test_get_s3_config():
    config = get_s3_config()
    assert config["endpoint"] == "http://localhost:4566"
    assert config["region"] == "us-east-1"
    assert config["access_key"] == "test_access_key"
    assert config["secret_key"] == "test_secret_key"
    assert config["bucket_name"] == "test_bucket"

@patch("app.app.boto3.client")
def test_create_s3_client(mock_boto_client):
    config = get_s3_config()
    create_s3_client(config)
    mock_boto_client.assert_called_once_with(
        's3',
        aws_access_key_id="test_access_key",
        aws_secret_access_key="test_secret_key",
        endpoint_url="http://localhost:4566"
    )

@patch("app.app.create_s3_client")
def test_s3_client_get_client(mock_create_s3_client):
    mock_create_s3_client.return_value = MagicMock()
    client = S3Client.get_client()
    assert client is not None
    mock_create_s3_client.assert_called_once()

@patch("app.app.S3Client.get_client")
def test_list_objects(mock_get_client):
    mock_s3_client = MagicMock()
    mock_get_client.return_value = mock_s3_client
    mock_s3_client.get_paginator.return_value.paginate.return_value = [
        {
            "CommonPrefixes": [{"Prefix": "folder1/"}, {"Prefix": "folder2/"}],
            "Contents": [{"Key": "file1.txt"}, {"Key": "folder1/file2.txt"}]
        }
    ]
    result = list_objects("")
    assert result == ["file1.txt", "folder1", "folder2"]

def test_list_endpoints():
    response = client.get("/")
    assert response.status_code == 200
    assert "endpoints" in response.json()

def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

@patch("app.app.list_objects")
def test_list_bucket_content(mock_list_objects):
    mock_list_objects.return_value = ["file1.txt", "folder1"]
    response = client.get("/list-bucket-content")
    assert response.status_code == 200
    assert response.json() == {"content": ["file1.txt", "folder1"]}

@patch("app.app.list_objects")
def test_list_bucket_content_not_found(mock_list_objects):
    mock_list_objects.return_value = None
    response = client.get("/list-bucket-content/nonexistentpath")
    assert response.status_code == 404
    assert response.json() == {"error": "Path 'nonexistentpath' does not exist in the bucket"}
    