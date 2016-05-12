# --- AWS authentication -------------------------------------------------------

variable "access_key" {}
variable "secret_key" {}
variable "region" {
  default = "ap-southeast-2"
}

# ------------------------------------------------------------------------------


# --- Provider instance --------------------------------------------------------

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

# ------------------------------------------------------------------------------


# --- module.vault -------------------------------------------------------------

variable "global_name" {}
variable "s3_bucket_name" {}
variable "ssh_public_key" {}
variable "iam_profile_name" {}

variable "vault_url" {
  default = "https://releases.hashicorp.com/vault/0.5.2/vault_0.5.2_linux_amd64.zip"
}

module "vault" {
  source           = "./modules/vault"
  global_name      = "${var.global_name}"
  s3_bucket_name   = "${var.s3_bucket_name}"
  ssh_public_key   = "${var.ssh_public_key}"
  iam_profile_name = "${var.iam_profile_name}"
  vault_url        = "${var.vault_url}"
  aws_access_key   = "${var.access_key}"
  aws_secret_key   = "${var.secret_key}"
}

# ------------------------------------------------------------------------------

output "Vault instance" {
  value = "export VAULT_ADDR=${module.vault.instance_ip}"
}
