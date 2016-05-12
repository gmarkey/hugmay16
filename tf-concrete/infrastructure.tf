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
variable "ssh_public_key" {}
variable "iam_profile_name" {}
variable "git_repo" {}
variable "test_script" {}

variable "terraform_url" {
  default = "https://releases.hashicorp.com/terraform/0.6.16/terraform_0.6.16_linux_amd64.zip"
}

module "concrete" {
  source           = "./modules/concrete"
  global_name      = "${var.global_name}"
  ssh_public_key   = "${var.ssh_public_key}"
  iam_profile_name = "${var.iam_profile_name}"
  terraform_url    = "${var.terraform_url}"
  git_repo         = "${var.git_repo}"
  test_script      = "${var.test_script}"
}

# ------------------------------------------------------------------------------

output "Concrete URL" {
  value = "${module.concrete.concrete_url}"
}
