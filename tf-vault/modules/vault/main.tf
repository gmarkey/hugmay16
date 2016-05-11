variable "global_name" {}
variable "ssh_public_key" {}
variable "user_data" {}
variable "s3_bucket_name" {}

variable "preferred_ami" {
  default = "ami-fedafc9d"
}

variable "bootstrap" {}

variable "ebs_size" {
  default = 40
}

variable "instance_type" {
  default = "t2.medium"
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

resource "aws_key_pair" "demo_pair" {
  key_name   = "demo_pair"
  public_key = "${file(var.ssh_public_key)}"
  
  lifecycle = {
    create_before_destroy = true
  }

}

resource "template_file" "user_data" {
  template = "${var.user_data}"

  vars {
    vault_container           = "${var.vault_container}"
    app_INIT_KEY_EMAIL        = "${var.app_INIT_KEY_EMAIL}"
    app_INIT_SMTP_SERVER      = "${var.app_INIT_SMTP_SERVER}"
    app_INIT_SERVICE_ID       = "${var.global_name}"
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
  bucket = "${var.s3_bucket_name}"

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_launch_configuration" "lc" {
  security_groups             = [ "${aws_security_group.allow_all.id}"  ]
  name_prefix                 = "${var.global_name}-"
  user_data                   = "${template_file.user_data.rendered}"
  instance_type               = "${var.instance_type}"
  image_id                    = "${var.preferred_ami}"
  iam_instance_profile        = "${module.aws.iam}"
  key_name                    = "${aws_key_pair.demo_pair.key_name}"
  associate_public_ip_address = false
  enable_monitoring           = false
  ebs_optimized               = false

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.ebs_size}"
  }

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_elb" "vault_api" {
  security_groups    = [ "${aws_security_group.allow_all.id}" ]
  availability_zones = [ "ap-southeast-2c" ]
  idle_timeout       = 3600

  cross_zone_load_balancing = true
  connection_draining       = true
  name                      = "${var.global_name}-api"

  health_check = {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    target              = "TCP:8200"
    interval            = 5
    timeout             = 2
  }

  listener = {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 80
    lb_protocol        = "http"
  }

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "asg" {
  availability_zones        = [ "ap-southeast-2c" ]
  load_balancers            = [ "${aws_elb.vault_api.name}" ]
  max_size                  = 1
  min_size                  = 1
  launch_configuration      = "${aws_launch_configuration.lc.name}"
  health_check_type         = "ELB"
  health_check_grace_period = 600
  wait_for_capacity_timeout = 0
  name                      = "${var.global_name}"

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_security_group" "allow_all" {
  name = "${var.global_name}-allow_all"
  description = "Lazy security group for demo purposes"

  ingress = {
    from_port   = 0
    to_port     = 0
    protocols   = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress = {
    from_port   = 0
    to_port     = 0
    protocols   = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  lifecycle = {
    create_before_destroy = true
  }

}

#provisioner "file" {
#  source      = "provision"
#  destination = "/tmp"
#
#  connection = {
#    user = "centos"
#  }
#
#}

output "name" {
  value = "${var.global_name}"
}

output "api_load_balancer" {
  value = "http://${aws_elb.vault_api.dns_name}"
}
