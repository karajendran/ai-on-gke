# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "rag"
}

variable "region" {
  type        = string
  description = "GCP project region"
}

variable "cloudsql_instance" {
  type        = string
  description = "Name of the CloudSQL instance for RAG VectorDB"
  default     = "pgvector-instance"
}

variable "cloudsql_instance_region" {
  type        = string
  description = "Name of the CloudSQL instance for RAG VectorDB"
}

variable "db_secret_name" {
  type        = string
  description = "CloudSQL user credentials"
}

variable "base_image" {
  type        = string
  description = "Base image for the application"
  default     = "us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke/frontend@sha256:8f40b9485739fb2b2b4d77e18f101e1030abff63d4a6240c4cfbf2c333b593fc"
}

variable "chat_history_image" {
  type        = string
  description = "Image that enables chat history via langchain + CloudSQL extensions"
  default     = "us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke/frontend-langchain@sha256:10f511678e69c110389a43cabcb33d8081b0955c2760e1e793c01b09dd68c3cb"
}

variable "dataset_embeddings_table_name" {
  type        = string
  description = "Name of the table that stores vector embeddings for input dataset"
}

variable "enable_chat_history" {
  type        = bool
  description = "Enables chat history"
  default     = true
}

variable "inference_service_endpoint" {
  type        = string
  description = "Model inference k8s service endpoint"
}

variable "create_service_account" {
  type        = bool
  description = "Creates a google service account & k8s service account & configures workload identity"
  default     = true
}

variable "google_service_account" {
  type        = string
  description = "Google Service Account name"
  default     = "frontend-gcp-sa"
}

variable "add_auth" {
  type        = bool
  description = "Enable iap authentication on frontend"
  default     = true
}

variable "k8s_ingress_name" {
  type    = string
  default = "frontend-ingress"
}

variable "k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "frontend-managed-cert"
}

variable "k8s_iap_secret_name" {
  type    = string
  default = "frontend-secret"
}

variable "k8s_backend_config_name" {
  type        = string
  description = "Name of the Backend Config on GCP"
  default     = "frontend-iap-config"
}

variable "k8s_backend_service_name" {
  type        = string
  description = "Name of the K8s Backend Service, this is defined by Frontend"
  default     = "rag-frontend"
}

variable "k8s_backend_service_port" {
  type        = number
  description = "Name of the K8s Backend Service Port"
  default     = 8080
}

variable "brand" {
  type        = string
  description = "name of the brand if there isn't already on the project. If there is already a brand for your project, please leave it blank and empty"
  default     = ""
}

variable "url_domain_addr" {
  type        = string
  description = "Domain provided by the user. If it's empty, we will create one for you."
  default     = ""
}

variable "url_domain_name" {
  type        = string
  description = "Name of the domain provided by the user. This var will only be used if url_domain_addr is not empty"
  default     = ""
}

variable "support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = "<email>"
}

variable "client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
  sensitive   = false
}

variable "members_allowlist" {
  type    = list(string)
  default = []
}