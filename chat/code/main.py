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

import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key

import json
from datetime import datetime, UTC
from uuid import uuid4

secret_name = os.environ.get('FINDLY_SECRET_NAME')

from langchain_qdrant import Qdrant
from langchain_voyageai import VoyageAIEmbeddings
from langchain_voyageai import VoyageAIRerank
from langchain_openai import ChatOpenAI    

from langchain.retrievers import ContextualCompressionRetriever

from langchain_core.runnables import (
    ConfigurableField,
    RunnablePassthrough
)

from langchain_core.prompts import (
    ChatPromptTemplate,
    MessagesPlaceholder
)
from langchain_core.messages import (
    HumanMessage,
    AIMessage
)
import pickle

from langchain.chains import create_history_aware_retriever
from langchain.chains import create_retrieval_chain
from langchain.chains.combine_documents import create_stuff_documents_chain

def get_secret(secret_name: str) -> dict:
    secret_name = secret_name
    region_name = "us-east-1"

    # Create a Secrets Manager client
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
content_hash_table_name = secret['CONTENT_HASH_TABLE_NAME']
session_id_history_table_name = secret['SESSION_ID_HISTORY_TABLE_NAME']
voyage_api_key = secret['VOYAGE_API_KEY']
qdrant_url = secret['QDRANT_URL']
qdrant_api_key = secret['QDRANT_API_KEY']
qdrant_collection_name = secret['QDRANT_COLLECTION_NAME']
openai_api_key = secret['OPENAI_API_KEY']

voyage_multilingual_2 = VoyageAIEmbeddings(model="voyage-multilingual-2", voyage_api_key=voyage_api_key)

voyage_reranker = VoyageAIRerank(
    model="rerank-1", voyage_api_key=voyage_api_key, top_k=5
)

llm=ChatOpenAI(
    openai_api_key=openai_api_key,
    model_name="gpt-4o",
    temperature=0.,
)

doc_store = Qdrant.from_existing_collection(
    embedding=voyage_multilingual_2,
    collection_name=qdrant_collection_name,
    url=qdrant_url,
    api_key=qdrant_api_key
)

retriever = doc_store.as_retriever(
    search_type="similarity"
)

compression_retriever = ContextualCompressionRetriever(
    base_compressor=voyage_reranker, base_retriever=retriever
)

configurable_compression_retriever = compression_retriever.base_retriever.configurable_fields(
    search_kwargs=ConfigurableField(
        id="search_kwargs",
        name="Search Kwargs",
        description="The search kwargs to use",
    )
)

contextualize_q_system_prompt = """Given a chat history and the latest user question \
which might reference context in the chat history, formulate a standalone question \
which can be understood without the chat history. Do NOT answer the question, \
just reformulate it if needed and otherwise return it as is."""

contextualize_q_system_prompt = ChatPromptTemplate.from_messages([
    ("system", contextualize_q_system_prompt),
    MessagesPlaceholder("chat_history"),
    ("human", "{input}")
])

# Kindly borrowed from user "ksmin23" at https://github.com/langchain-ai/langchain/issues/9195#issuecomment-2095196865
# and adapted to use the use contextual compression

history_aware_configurable_retriever = create_history_aware_retriever(
    llm, configurable_compression_retriever, contextualize_q_system_prompt
)

qa_system_prompt = """You are an assistant for question-answering tasks. \
Use the following pieces of retrieved context to answer the question. \
If you don't know the answer, just say that you don't know. \
Use three sentences maximum and keep the answer concise.\

{context}"""

qa_prompt = ChatPromptTemplate.from_messages([
    ("system", qa_system_prompt),
    MessagesPlaceholder("chat_history"),
    ("human", "{input}")
])

question_answer_chain = create_stuff_documents_chain(llm, qa_prompt)

configurable_rag_chain = create_retrieval_chain(history_aware_configurable_retriever, question_answer_chain)

def get_latest_hash(url: str, datetime_str: str) -> str:
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(content_hash_table_name)
    # query table by url and before current datetime, get most recent entry
    response = table.query(KeyConditionExpression=Key('url').eq(url) & Key('last_retrieved').lte(datetime_str), IndexName='datetime_index', ScanIndexForward=False, Limit=1)
    logger.debug(response)
    items = response.get('Items', [])
    if items:
        item = items[0]
        return item.get('content_hash', None), item.get('last_retrieved', None)
    else:
        return None, None


def lambda_handler(event, context):
    body = json.loads(event['body'])
    url = body['url']
    query = body['query']
    session_id = body.get('session_id', str(uuid4()))

    datetime_str = datetime.now(UTC).isoformat()
    logger.info(f"Querying {url} with question: {query} (current datetime: {datetime_str})")

    latest_hash, last_retrieved = get_latest_hash(url, datetime_str)
    if latest_hash is None:
        logger.warning(f"Url {url} was not yet indexed.")
        return {
            "isBase64Encoded": False,
            "statusCode": 418,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": f"Url {url} was not yet indexed in the vector store. Index the url first before querying. (Use the /index-url endpoint and wait a little bit before querying again.)"
            })
        }

    logger.info(f"Url found in vector store. Latest hash: {latest_hash} (last retrieved: {last_retrieved})")

    pre_filter = {
        "url": url,
        "content_hash": latest_hash,
    }
    
    config = {
        "configurable": {
            "search_kwargs": {
                "k": 20,
                "filter": pre_filter,
            }
        }
    }
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(session_id_history_table_name)
    response = table.get_item(Key={'session_id': session_id})
    item = response.get('Item')
    logger.debug(item)
    if item:
        logger.info(f"Found chat history for session_id: {session_id}")
        chat_history = pickle.loads(bytes(item['chat_history']))
    else:
        logger.info(f"Chat history not found for session_id: {session_id}. Creating a new chat history.") 
        chat_history = []
   
    llm_response = configurable_rag_chain.invoke({"input": query, "chat_history": chat_history}, config=config)
    llm_answer = llm_response["answer"]
    
    chat_history.extend([HumanMessage(content=query), AIMessage(content=llm_answer)])

    table.put_item(Item={'session_id': session_id, 'chat_history': pickle.dumps(chat_history)})

    logger.info(f"Answer: {llm_answer}")
    return {
        "isBase64Encoded": False,
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "question": query,
            "url": url,
            "last_retrieved": last_retrieved,
            "content_hash": latest_hash,
            "session_id": session_id,
            "chat_history": str(chat_history),
            "answer": llm_answer,
        })
    }
