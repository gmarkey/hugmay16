variable "region" {
  default = "ap-southeast-2"
}

variable "environment" {
  default = "np"
}

variable "service" {
  default = "vault"
}

variable "role" {
  default = "master"
}

variable "cluster" {}
variable "owner" {}
variable "startstop" {}

/* Module specific */
variable "user_data" {}

variable "ebs_size" {
  default = 40
}

variable "instance_type" {
  default = "t2.micro"
}

variable "app_INIT_KEY_EMAIL" {}

variable "app_INIT_SMTP_SERVER" {
  default = "mail.comp.optiver.com:25"
}

variable "app_AWS_ACCESS_KEY_ID" {}
variable "app_AWS_SECRET_ACCESS_KEY" {}
variable "app_VAULT_UNSEAL_KEYS" {
  default = ""
}

variable "app_VAULT_TLS_DISABLE" {
  default = "0"
}

variable "vault_container" {}

/**/

module "aws" {
  source      = "../terraform-aws-common"
  region      = "${var.region}"
  environment = "${var.environment}"
  service     = "${var.service}"
  role        = "${var.role}"
  cluster     = "${var.cluster}"
  owner       = "${var.owner}"
  startstop   = "${var.startstop}"
}

/* Workarounds for https://github.com/hashicorp/terraform/issues/4149 */
module "name" {
  source = "../terraform-intermediate"
  v      = "${var.service}-${var.environment}-${var.cluster}"
}

resource "template_file" "user_data" {
  template = "${var.user_data}"

  vars {
    vault_container           = "${var.vault_container}"
    app_INIT_KEY_EMAIL        = "${var.app_INIT_KEY_EMAIL}"
    app_INIT_SMTP_SERVER      = "${var.app_INIT_SMTP_SERVER}"
    app_INIT_SERVICE_ID       = "${module.name.v}"
    app_AWS_S3_BUCKET         = "${aws_s3_bucket.bucket.id}"
    app_AWS_ACCESS_KEY_ID     = "${var.app_AWS_ACCESS_KEY_ID}"
    app_AWS_SECRET_ACCESS_KEY = "${var.app_AWS_SECRET_ACCESS_KEY}"
    app_VAULT_UNSEAL_KEYS     = "${var.app_VAULT_UNSEAL_KEYS}"
    app_VAULT_TLS_DISABLE     = "${var.app_VAULT_TLS_DISABLE}"
  }

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_s3_bucket" "bucket" {
  bucket = "optiver-${module.name.v}"
}

resource "aws_launch_configuration" "lc" {
  security_groups             = [ "${split(",", module.aws.sg)}" ]
  name_prefix                 = "${module.name.v}-"
  user_data                   = "${template_file.user_data.rendered}"
  instance_type               = "${var.instance_type}"
  image_id                    = "${module.aws.ami_centos}"
  iam_instance_profile        = "${module.aws.iam}"
  key_name                    = "${module.aws.pubkey}"
  associate_public_ip_address = false
  enable_monitoring           = false
  ebs_optimized               = false

  root_block_device = {
    volume_type = "gp2"
    volume_size = 40
  }

  ebs_block_device = {
    device_name = "/dev/sdf"
    volume_type = "gp2"
    volume_size = "${var.ebs_size}"
  }

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_elb" "vault_api" {
  security_groups = [ "${split(",", module.aws.sg)}" ]
  subnets         = [ "${split(",", module.aws.subnet_id)}" ]
  internal        = true
  idle_timeout    = 3600

  health_check = {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    target              = "TCP:8200"
    interval            = 5
    timeout             = 2
  }

  /* Listener for secure API */
  listener = {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${module.aws.ssl_cert}"
  }

  cross_zone_load_balancing = true
  connection_draining       = true
  name                      = "${module.name.v}"

  tags {
    Environment = "${var.environment}"
    Service     = "${var.service}"
    Cluster     = "${var.cluster}"
    Owner       = "${var.owner}"
  }

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier       = [ "${split(",", module.aws.subnet_id)}" ]
  load_balancers            = [ "${aws_elb.vault_api.name}" ]
  max_size                  = 1
  min_size                  = 1
  launch_configuration      = "${aws_launch_configuration.lc.name}"
  health_check_type         = "ELB"
  health_check_grace_period = 600
  wait_for_capacity_timeout = 0
  name                      = "${module.name.v}"

  tag = {
    key   = "Name"
    value = "${module.name.v}"
    propagate_at_launch = true
  }

  tag = {
    key   = "Environment"
    value = "${var.environment}"
    propagate_at_launch = true
  }

  tag = {
    key   = "Service"
    value = "${var.service}"
    propagate_at_launch = true
  }

  tag = {
    key   = "Role"
    value = "${var.role}"
    propagate_at_launch = true
  }

  tag = {
    key   = "Cluster"
    value = "${var.cluster}"
    propagate_at_launch = true
  }

  tag = {
    key   = "Owner"
    value = "${var.owner}"
    propagate_at_launch = true
  }

  tag = {
    key   = "StartStop"
    value = "${var.startstop}"
    propagate_at_launch = true
  }

  lifecycle = {
    create_before_destroy = true
  }

}

output "name" {
  value = "${module.name.v}"
}

output "api_load_balancer" {
  value = "https//${aws_elb.vault_api.dns_name}"
}
