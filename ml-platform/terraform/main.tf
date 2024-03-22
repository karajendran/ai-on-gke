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

locals {
  project = data.google_project.enviroment
}

module "gcp-project" {
  source = "./modules/projects"

  billing_account = var.billing_account
  env             = var.environment_name
  folder_id       = var.folder_id
  org_id          = var.org_id
  project_id      = var.environment_project_id
  project_name    = var.project_name
}

data "google_project" "enviroment" {
  project_id = module.gcp-project.project_id
}

resource "google_project_service" "anthos_googleapis_com" {
  depends_on = [
    google_project_service.monitoring_googleapis_com
  ]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "anthos.googleapis.com"
}

resource "google_project_service" "anthosconfigmanagement_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "anthosconfigmanagement.googleapis.com"
}

# resource "google_project_service" "autoscaling_googleapis_com" {
#   disable_dependent_services = false
#   disable_on_destroy         = true
#   project                    = local.project.project_id
#   service                    = "autoscaling.googleapis.com"
# }

resource "google_project_service" "cloudresourcemanager_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "compute_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "compute.googleapis.com"
}

resource "google_project_service" "connectgateway_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "connectgateway.googleapis.com"
}

resource "google_project_service" "container_googleapis_com" {
  # depends_on = [
  #   google_project_service.monitoring_googleapis_com
  # ]

  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "container.googleapis.com"
}

resource "google_project_service" "containerfilesystem_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "containerfilesystem.googleapis.com"
}

resource "google_project_service" "gkeconnect_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false  #Currently cannot disabled due to circular dependency
  project                    = local.project.project_id
  service                    = "gkeconnect.googleapis.com"
}

resource "google_project_service" "gkehub_googleapis_com" {
  disable_dependent_services = false
  disable_on_destroy         = false  #Currently cannot disabled due to circular dependency
  project                    = local.project.project_id
  service                    = "gkehub.googleapis.com"
}

resource "google_project_service" "iam_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "iam.googleapis.com"
}

resource "google_project_service" "logging_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "logging.googleapis.com"
}

resource "google_project_service" "monitoring_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "monitoring.googleapis.com"
}

resource "google_project_service" "serviceusage_googleapis_com" {
  disable_dependent_services = true
  disable_on_destroy         = true
  project                    = local.project.project_id
  service                    = "serviceusage.googleapis.com"
}

module "create-vpc" {
  source = "./modules/network"

  depends_on = [
    google_project_service.compute_googleapis_com
  ]

  network_name     = format("%s-%s", var.network_name, var.environment_name)
  project_id       = local.project.project_id
  routing_mode     = var.routing_mode
  subnet_01_ip     = var.subnet_01_ip
  subnet_01_name   = format("%s-%s", var.subnet_01_name, var.environment_name)
  subnet_01_region = var.subnet_01_region
  subnet_02_ip     = var.subnet_02_ip
  subnet_02_name   = format("%s-%s", var.subnet_02_name, var.environment_name)
  subnet_02_region = var.subnet_02_region
}

resource "google_gke_hub_fleet" "environment" {
  depends_on = [
    google_project_service.container_googleapis_com,
    google_project_service.gkehub_googleapis_com
  ]

  display_name = "${local.project.project_id} Fleet"
  project      = local.project.project_id

  default_cluster_config {
    binary_authorization_config {
    }

    security_posture_config {
    }
  }
}

resource "google_gke_hub_feature" "configmanagement" {
  depends_on = [
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.container_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com
  ]

  location = "global"
  name     = "configmanagement"
  project  = local.project.project_id
}

module "gke" {
  source = "./modules/cluster"

  depends_on = [
    google_gke_hub_fleet.environment
  ]

  cluster_name                = format("%s-%s", var.cluster_name, var.environment_name)
  env                         = var.environment_name
  master_auth_networks_ipcidr = var.subnet_01_ip
  network                     = module.create-vpc.vpc
  project_id                  = local.project.project_id
  region                      = var.subnet_01_region
  subnet                      = module.create-vpc.subnet-1
  zone                        = "${var.subnet_01_region}-a"
}

module "reservation" {
  source = "./modules/vm-reservations"

  cluster_name = module.gke.cluster_name
  project_id   = local.project.project_id
  zone         = "${var.subnet_01_region}-a"
}

module "node_pool-reserved" {
  source = "./modules/node-pools"

  depends_on = [
    google_project_service.container_googleapis_com,
    module.gke
  ]

  cluster_name     = module.gke.cluster_name
  node_pool_name   = "reservation"
  project_id       = local.project.project_id
  region           = var.subnet_01_region
  reservation_name = module.reservation.reservation_name
  resource_type    = "reservation"
  taints           = var.reserved_taints
}

module "node_pool-ondemand" {
  source = "./modules/node-pools"

  depends_on = [
    google_project_service.container_googleapis_com,
    module.gke
  ]

  cluster_name   = module.gke.cluster_name
  node_pool_name = "ondemand"
  project_id     = local.project.project_id
  region         = var.subnet_01_region
  resource_type  = "ondemand"
  taints         = var.ondemand_taints
}

module "node_pool-spot" {
  source = "./modules/node-pools"

  depends_on = [
    google_project_service.container_googleapis_com,
    module.gke
  ]

  cluster_name   = module.gke.cluster_name
  node_pool_name = "spot"
  project_id     = local.project.project_id
  region         = var.subnet_01_region
  resource_type  = "spot"
  taints         = var.spot_taints
}

module "cloud-nat" {
  source = "./modules/cloud-nat"

  create_router = true
  name          = format("%s-%s", "nat-for-acm", var.environment_name)
  network       = module.create-vpc.vpc
  project_id    = local.project.project_id
  region        = split("/", module.create-vpc.subnet-1)[3]
  router        = format("%s-%s", "router-for-acm", var.environment_name)
}

resource "google_gke_hub_membership" "membership" {
  depends_on = [
    google_gke_hub_feature.configmanagement,
    google_project_service.gkehub_googleapis_com
  ]

  membership_id = module.gke.cluster_name
  project       = module.gke.gke_project_id

  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${module.gke.cluster_id}"
    }
  }
}

resource "github_repository" "config_sync" {
  allow_merge_commit     = true
  allow_rebase_merge     = true
  allow_squash_merge     = true
  auto_init              = true
  delete_branch_on_merge = false
  description            = "Repo for Config Sync"
  has_issues             = false
  has_projects           = false
  has_wiki               = false
  name                   = var.configsync_repo_name
  visibility             = "private"
  vulnerability_alerts   = true
}

resource "github_branch" "environment" {
  branch     = var.environment_name
  repository = github_repository.config_sync.name
}

resource "github_branch_default" "config_sync_default" {
  branch     = github_branch.environment.branch
  repository = github_repository.config_sync.name
}

resource "github_branch_protection_v3" "branch_protection" {
  repository = github_repository.config_sync.name
  branch     = github_branch.environment.branch

  required_pull_request_reviews {
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }

  restrictions {
  }
}

resource "google_gke_hub_feature_membership" "feature_member" {
  depends_on = [
    google_project_service.anthos_googleapis_com,
    google_project_service.anthosconfigmanagement_googleapis_com,
    google_project_service.gkeconnect_googleapis_com,
    google_project_service.gkehub_googleapis_com
  ]

  feature    = "configmanagement"
  location   = "global"
  membership = google_gke_hub_membership.membership.membership_id
  project    = local.project.project_id

  configmanagement {
    version = var.config_management_version

    config_sync {
      source_format = "unstructured"

      git {
        policy_dir  = "manifests/clusters"
        secret_type = "token"
        sync_branch = github_branch.environment.branch
        sync_repo   = github_repository.config_sync.http_clone_url
      }
    }

    policy_controller {
      enabled                    = true
      referential_rules_enabled  = true
      template_library_installed = true
    }
  }
}

resource "null_resource" "create_cluster_yamls" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_cluster_yamls.sh ${var.github_org} ${github_repository.config_sync.full_name} ${var.github_user} ${var.github_email} ${var.environment_name} ${module.gke.cluster_name} 0"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template", "**") : md5("${path.module}/templates/acm-template/${f}")]))
    md5_script = filemd5("${path.module}/scripts/create_cluster_yamls.sh")
  }
}

resource "null_resource" "create_git_cred_cms" {
  depends_on = [
    google_gke_hub_membership.membership
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${module.gke.cluster_name} ${local.project.project_id} ${var.github_user} config-management-system 0"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
  }
}

resource "null_resource" "install_kuberay_operator" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_cms
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_kuberay_operator.sh ${github_repository.config_sync.full_name} ${var.github_email} ${var.github_org} ${var.github_user}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/kuberay", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/kuberay/${f}")]))
    md5_script = filemd5("${path.module}/scripts/install_kuberay_operator.sh")
  }
}

resource "google_service_account" "namespace_default" {
  account_id   = "wi-${var.namespace}-default"
  display_name = "${var.namespace} Default Workload Identity Service Account"
  project      = local.project.project_id
}

resource "google_service_account_iam_member" "wi_environment_workload_identity_user" {
  depends_on = [
    module.gke
  ]

  member             = "serviceAccount:${local.project.project_id}.svc.id.goog[${var.namespace}/${var.namespace}-default]"
  role               = "roles/iam.workloadIdentityUser"
  service_account_id = google_service_account.namespace_default.id
}

resource "null_resource" "create_namespace" {
  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.install_kuberay_operator
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_namespace.sh ${github_repository.config_sync.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${var.environment_name}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template/templates/_cluster_template/team", "**") : md5("${path.module}/templates/acm-template/templates/_cluster_template/team/${f}")]))
    md5_script = filemd5("${path.module}/scripts/create_namespace.sh")
  }
}

resource "null_resource" "create_git_cred_ns" {
  count = var.create_namespace

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_namespace
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/create_git_cred.sh ${module.gke.cluster_name} ${module.gke.gke_project_id} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_credentials = md5(join("", [var.github_user, var.github_token]))
    md5_script      = filemd5("${path.module}/scripts/create_git_cred.sh")
  }
}

resource "null_resource" "install_ray_cluster" {
  count = var.install_ray_in_ns

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/install_ray_cluster.sh ${github_repository.config_sync.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace} ${google_service_account.namespace_default.email}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_files  = md5(join("", [for f in fileset("${path.module}/templates/acm-template//templates/_namespace_template/app", "**") : md5("${path.module}/templates/acm-template//templates/_namespace_template/app/${f}")]))
    md5_script = filemd5("${path.module}/scripts/install_ray_cluster.sh")
  }
}

resource "null_resource" "manage_ray_ns" {
  count = var.install_ray_in_ns

  depends_on = [
    google_gke_hub_feature_membership.feature_member,
    null_resource.create_git_cred_ns,
    null_resource.install_ray_cluster
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/manage_ray_ns.sh ${github_repository.config_sync.full_name} ${var.github_email} ${var.github_org} ${var.github_user} ${var.namespace}"
    environment = {
      GIT_TOKEN = var.github_token
    }
  }

  triggers = {
    md5_script = filemd5("${path.module}/scripts/manage_ray_ns.sh")
  }
}
