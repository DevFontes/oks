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
