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
