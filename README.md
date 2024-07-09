# Project Overview

Prototype developed for the Findly RAG Challenge, featuring contextual compression based on a reranker approach, implemented with LangChain. 

This repository provides Infrastructure as Code (IaC) for deploying a complete backend system using AWS services. The system is composed of six main components that form the building blocks of the REST API.

## Highlights
- [x] **Cost Efficiency**: Avoids reindexing unchanged webpages, reducing costly external API calls.
- [x] **Contextual Compression**: Utilizes a **reranker** to improve data processing efficiency and precision.
- [x] **Performance-Optimized Database**: Employs **Qdrant**, a vector database built in Rust for high performance.
- [x] **Framework Utilization**: Integrates the open-source **LangChain** framework for advanced language processing capabilities.
- [x] **Dynamic Metadata Filtering**: Passing the URL filter to the base retriever **on-the-go** os that only content from the correct URL passes to the contextual compressor.
- [x] **Cloud Deployment**: Fully deployed on AWS for **scalability and reliability**.
- [x] **Infrastructure as Code**: All components are managed using Terraform, ensuring **reproducibility and maintainability**.

## Try It Out
REST API: [`https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1`](https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1)

### Endpoint: [`/index_url`](https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1/index_url)
Indexes a given URL asynchronously. First, the text of the webpage is extracted and hashed. If the current content of the URL has not been indexed yet, the content is split into chunks (with some overlap), which are then asynchronously indexed using the embeddings from [`voyage-multilingual-2`](https://docs.voyageai.com/docs/embeddings) and inserted into the [Qdrant](https://qdrant.tech/) vector database. This API method always returns immediately with status code 200 and empty response body, not depending on whether or not the content has already been indexed before. Due to this fact, it is recommended to wait at least 30 seconds before asking a question to a URL that was just indexed.

API Key Required: yes

HTTP Method: `POST`

Required Keys: 
- "url": The URL to index.
  
**Example Request**
```bash
curl -H "x-api-key: ..." -X POST -d '{"url": "https://en.wikipedia.org/wiki/Brazil"}' https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1/index_url
```

### Endpoint: [`/ask`](https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1/ask)
Answers a question based on the content of a given, previously indexed, URL. This is done by calculating the embedding of the given question with respect to [`voyage-multilingual-2`](https://docs.voyageai.com/docs/embeddings). In the following, the 20 closest most vectors (with respect to the cosine similarity measure) corresponding to the content chunks of the given URL are extracted from the [Qdrant](https://qdrant.tech/) vector database and passed on to the contextual compressor, which then ranks the top 5 matching documents using the [`rerank-1`](https://docs.voyageai.com/docs/reranker) reranker. Finally a the [GPT-4o](https://platform.openai.com/docs/models/gpt-4o) LLM is invoked in order to extract the desired information from the top matching documents and answer the question.
This API method waits until the answer is found. However, the timeout is limited to 29s by the REST API. 

API Key Required: yes

HTTP Method: `POST`

Required Keys: 
- "url": The URL based on which the question should be answered.
- "query": The question that should be answered.

Returns:
- "question": The original question.
- "url": The URL based on which the question was answered.
- "last_retrieved": The datetime in ISO format at which the URL was last retrieved.
- "content_hash": The hash of the last version of the content of the URL
- "answer": The answer provided by the LLM.

**Example Request**
```bash
curl -H "x-api-key: ..." -X POST -d '{"url": "https://en.wikipedia.org/wiki/Brazil", "query": "What is the population of Brazil?"}' https://ethsgne5kk.execute-api.us-east-1.amazonaws.com/v1/ask
```
**Example Output**
```bash
{
  "question": "What is the population of Brazil?",
  "url": "https://en.wikipedia.org/wiki/Brazil",
  "last_retrieved": "2024-07-09T01:28:58.292102+00:00",
  "content_hash": "ca985af177cedca9913f0b919ffac190",
  "answer": "The population of Brazil, as recorded by the 2008 PNAD, was approximately 190 million."
}
```
(Note that a more recent information indeed does not appear in the continuous text, but rather in the informative table. In order to extract table data reliably, more development is needed. See below in [Next Steps](#next-steps))

## External Services
- [Voyage AI](https://www.voyageai.com/):
  - [Embeddings](https://docs.voyageai.com/docs/embeddings) (e.g. `voyage-multilingual-2`)
  - [Reranker](https://docs.voyageai.com/docs/reranker) (e.g. `rerank-1`)
- [OpenAI](https://openai.com/api/):
  - LLM (e.g. [GPT-4o](https://platform.openai.com/docs/models/gpt-4o))
- [Qdrant](https://qdrant.tech/)
  - [Managed Vector Database](https://qdrant.tech/qdrant-vector-database/)

## Components
The project is divided into the following components:

**API Endpoints** (Deployed as AWS Lambda Functions):
- [`/index_url`](index_url): Endpoint for indexing a URL.
- [`/ask`](ask): Endpoint for querying a URL.

**Lambda Layers**:
- [`langchain-layer`](langchain-layer): Contains dependencies for language processing.
- [`utils-layer`](utils-layer): Includes commonly used dependencies used across different Lambda functions.

**DynamoDB Tables**:
- [`url-content-hash_DynamoDB-table`](url-content-hash_DynamoDB-table): Maintains a hash of URL contents for quick lookup.
- `session-id-history_DynamoDB-table`: Stores session IDs and their chat history. (Not yet implemented...)

**API Gateway**:
- [`api-gateway-rest-api`](api-gateway-rest-api): Manages REST API interfacing for the Lambda functions.

Each component's code is organized in the repository as follows:
- **Terraform Configuration**: Located in the `terraform` subfolder.
- **Lambda Function Code** (if applicable): Python 3.12 code in the `code` subfolder.

## Deployment Instructions
### AWS Lambda Function (if applicable)
1. Navigate to the `code` directory:
   ```bash
   cd code
   ```
2. Remove old `project.zip` (if applicable):
   ```bash
   rm ../terraform/project.zip
   ```
3. Create zip file:
   ```bash
   zip -r ../terraform/project.zip .
   ```

### AWS Lambda Layer (if applicable)
1. Navigate to the `layer` directory:
   ```bash
   cd layer
   ```
2. Remove old `{layer-name}.zip` (if applicable):
   ```bash
   rm ../terraform/{layer-name}.zip
   ```
3. Install `requirements.txt`:
   ```bash
   python3.12 -m pip install -r requirements.txt --target python/lib/python3.12/site-packages/
   ```
4. Create zip file:
   ```bash
   zip -r ../terraform/{layer-name}.zip python/
   ```
### Terraform
Follow these steps to deploy the components using Terraform:

1. Navigate to the Terraform configuration directory:
   ```bash
   cd terraform
   ```
2. Initialize the Terraform configuration:
   ```bash
   terraform init
   ```
3. Validate the Terraform configuration:
   ```bash
   terraform validate
   ```
4. Create an execution plan: (using a your custom variables file, e.g. "development.tfvars")
   ```bash
   terraform plan [-var-file development.tfvars] -out "planfile"
   ```
5. Apply the plan to create or update resources:
   ```bash
   terraform apply "planfile"
   ```

### Important Notes
- Ensure that the `variables.tf` and `main.tf` files are updated with the necessary configurations specific to your environment.
- Manually create the necessary secrets (e.g., API keys) in AWS Secrets Manager prior to deployment. The AWS Lambda functions require the following variables set:
  - `CONTENT_HASH_TABLE_NAME`
  - `QDRANT_URL`
  - `QDRANT_API_KEY`
  - `QDRANT_COLLECTION_NAME`
  - `VOYAGE_API_KEY`
  - `OPENAI_API_KEY`

## Next Steps
- [ ] Implement chat endpoint with session ID in order to enable chat history.
- [ ] Rewrite AWS Lambda Handlers using Flask.
- [ ] Write OpenAPI documentation of the endpoints.
- [ ] Use webhooks in order to overcome the REST API timeout of 29 seconds.
- [ ] Extract information from tables reliably with Beautifulsoup.
- [ ] Deploy [Qdrant](https://qdrant.tech/) as a container on an EC2 instance via Terraform. (If it makes sense in terms of cost reduction.)
- [ ] Deploy dedicated instances of open-source Huggingface LLMs for embedding, reranking and chat. (If it makes sense in terms of cost reduction.)
