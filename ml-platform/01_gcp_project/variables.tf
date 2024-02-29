# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "org_id" {
  type        = string
  description = "The GCP orig id"
  default     = "YOUR_GCP_ORG_ID"
}

variable "env" {
  type        = set(string)
  description = "List of environments"
  default     = ["dev"]
}

variable "folder_id" {
  type        = string
  description = "Folder Id where the GCP projects will be created"
  default     = null
}

variable "billing_account" {
  type        = string
  description = "GCP billing account"
  default     = "YOUR_BILLING_ACCOUNT"
}

variable "project_name" {
  type        = string
  description = "GCP project name"
  default     = "ml-platform"
}