provider "google" {
  project = var.project
  zone    = var.zone
}

terraform {
  required_version = ">= 0.13"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "kubernetes" {
  host                   = resource.google_container_cluster.cluster1.endpoint
  cluster_ca_certificate = base64decode(resource.google_container_cluster.cluster1.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "kubectl" {
  host                   = resource.google_container_cluster.cluster1.endpoint
  cluster_ca_certificate = base64decode(resource.google_container_cluster.cluster1.master_auth.0.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}