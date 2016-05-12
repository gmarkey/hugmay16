variable "global_name" {}
variable "ssh_public_key" {}
variable "s3_bucket_name" {}
variable "iam_profile_name" {}
variable "vault_url" {}

variable "preferred_ami" {
  default = "ami-fedafc9d"
}

variable "ebs_size" {
  default = 10
}

variable "instance_type" {
  default = "t2.micro"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}

/**/

resource "aws_key_pair" "demo_pair" {
  key_name   = "demo_pair_vault"
  public_key = "${var.ssh_public_key}"
  
  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.s3_bucket_name}"
  force_destroy = true

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_instance" "vault" {
  availability_zone           = "ap-southeast-2c"
  security_groups             = [ "${aws_security_group.allow_all.name}" ]
  ami                         = "${var.preferred_ami}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.demo_pair.key_name}"
  iam_instance_profile        = "${var.iam_profile_name}"
  associate_public_ip_address = false
  monitoring                  = false
  ebs_optimized               = false

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.ebs_size}"
  }

  tags = {
    Name = "vault"
  }

  lifecycle = {
    create_before_destroy = true
  }

  provisioner "file" {
    source      = "${path.root}/provision/vault.hcl.tmpl"
    destination = "/home/centos/vault.hcl.tmpl"

    connection = {
      user = "centos"
    }

  }

  provisioner "file" {
    source      = "${path.root}/provision/vault.sh"
    destination = "/home/centos/vault.sh"

    connection = {
      user = "centos"
    }

  }

  provisioner "remote-exec" {
    inline = [
      "echo export s3_bucket_name=${var.s3_bucket_name} >> environment",
      "echo export aws_access_key=${var.aws_access_key} >> environment",
      "echo export aws_secret_key=${var.aws_secret_key} >> environment",
      "chmod +x vault.sh",
      "./vault.sh"
    ]

    connection = {
      user = "centos"
    }

  }

}

resource "aws_security_group" "allow_all" {
  name = "${var.global_name}-allow_all"
  description = "Lazy security group for demo purposes"

  ingress = {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress = {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  lifecycle = {
    create_before_destroy = true
  }

}

output "name" {
  value = "${var.global_name}"
}

output "instance_ip" {
  value = "http://${aws_instance.vault.public_ip}:8200"
}
