import os

try:
    # Check for custom library
    from formatted_logging import get_and_configure_logger
    # Create logger with adequate formatting
    loglevel = os.getenv("LAMBDA_LOGLEVEL", "20")
    logger = get_and_configure_logger(__name__, int(loglevel))
except ImportError:
    # If custom library is not found, use default logging
    import logging
    logger = logging.getLogger()

import requests
import bs4
from hashlib import shake_128
import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
import json

import os
from datetime import datetime, UTC

secret_name = os.environ.get('FINDLY_SECRET_NAME')

from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_voyageai import VoyageAIEmbeddings
from langchain_qdrant import Qdrant
import asyncio

def get_secret(secret_name: str) -> dict:
    secret_name = secret_name
    region_name = "us-east-1"

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        raise e

    secret = get_secret_value_response['SecretString']

    return json.loads(secret)

secret = get_secret(secret_name)
table_name = secret['CONTENT_HASH_TABLE_NAME']
voyage_api_key = secret['VOYAGE_API_KEY']
qdrant_url = secret['QDRANT_URL']
qdrant_api_key = secret['QDRANT_API_KEY']
qdrant_collection_name = secret['QDRANT_COLLECTION_NAME']

voyage_multilingual_2 = VoyageAIEmbeddings(model="voyage-multilingual-2", voyage_api_key=voyage_api_key)

doc_store = Qdrant.from_existing_collection(
    embedding=voyage_multilingual_2,
    collection_name=qdrant_collection_name,
    url=qdrant_url,
    api_key=qdrant_api_key
)

def get_page_content(url: str) -> str:
    res = requests.get(url)
    res.raise_for_status()

    wiki = bs4.BeautifulSoup(res.text,"html.parser")

    content = wiki.get_text() 
    return content

def get_shake_128_hash(content: str) -> str:
    return shake_128(content.encode("utf-8")).hexdigest(16)

# check if the hash already exists in the DynamoDB table
def check_hash_exists(url: str, content_hash: str) -> bool:
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)
    response = table.get_item(Key={'url': url, 'content_hash': content_hash})
    return 'Item' in response

def update_hash(url: str, content_hash: str, datetime_str: str) -> bool:
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)
    table.update_item(
        Key={'url': url, 'content_hash': content_hash},
        UpdateExpression="set last_retrieved=:u",
        ExpressionAttributeValues={':u': datetime_str}
    )

def get_text_chunks_langchain(text: str, url: str, content_hash: str) -> list:
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=250)
    docs = [Document(page_content=x, metadata={"url": url, "content_hash": content_hash}) for x in text_splitter.split_text(text)]
    return docs

def lambda_handler(event, context):
    url = event['url']
    logger.info(f'Received request to index webpage content for {url}')

    content = get_page_content(url)
    content_hash = get_shake_128_hash(content)

    now = datetime.now(UTC)
    
    if check_hash_exists(url, content_hash):
        logger.info(f'Webpage content for {url} has already been indexed previously. (Content hash: {content_hash})')
    else:
        docs = get_text_chunks_langchain(content, url, content_hash)
        len_docs = len(docs)
        logger.info(f'Webpage content for {url} has been split into {len_docs} documents.')
        loop = asyncio.get_event_loop()
        if loop.is_closed(): 
            loop = asyncio.new_event_loop()
        loop.run_until_complete(doc_store.aadd_documents(docs))
        update_hash(url, content_hash, now.isoformat())
        logger.info(f'Webpage content for {url} indexed successfully. (Content hash: {content_hash})')
    update_hash(url, content_hash, now.isoformat())

