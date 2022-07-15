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
terraform apply
```

## Delete your cluster
```sh
terraform destroy
```

