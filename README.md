This script will build 1 GKE clusters thanks to Terraform. 

## Requirements

<ul>
<li> Google Cloud SDK <a href="https://cloud.google.com/sdk/docs/install"> install </a> </li>
<li> Terraform <a href="https://learn.hashicorp.com/tutorials/terraform/install-cli"> install </a> </li>
</ul>

## Setup
1) Login into your GCP account
```sh
gcloud auth application-default login
gcloud auth login
```
2) Install/Update Terraform providers 
```sh
cd terraform
terraform init
terraform plan
```
## Create your cluster
```sh
terraform apply
```
## Delete your cluster
```sh
terraform destroy
```
## Notes
There are still updates to be made, pv-pod is yet to be implemented, argo is already installed but to submit worksflows you must first:
```sh
# Download the binary
curl -sLO https://github.com/argoproj/argo/releases/download/v2.11.1/argo-linux-amd64.gz

# Unzip
gunzip argo-linux-amd64.gz

# Make binary executable
chmod +x argo-linux-amd64

# Move binary to path
sudo mv ./argo-linux-amd64 /usr/local/bin/argo
```
