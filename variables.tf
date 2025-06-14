variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_id" {
  default = "" # será lido de OCI env var
}
variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "public_ip" {
  description = "Seu IP para acesso SSH, ex: 200.100.50.25/32"
  default     = "0.0.0.0/0" # use var.PUBLIC_IP se preferir travar
}

variable "route53_zone_id" {
  description = "ID da zona do Route53"
  default     = "" # será lido de AWS env var
}

variable "domain" {
  description = "Domínio para o cluster K3s"
  default     = "example.com" # ajuste conforme necessário
}

variable "ssh_private_key_path" {
  description = "Caminho para a chave privada SSH"
  default     = "~/.ssh/id_rsa"
}

variable "aws_access_key_id" {
  description = "Chave de acesso AWS"
  default     = "" # será lido de AWS env var  
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "AWS Region for Route53"
  default     = ""
}

variable "k3s_api_dns" {
  description = "DNS do endpoint da API do K3s"
  default     = "example.com"
  type        = string
}