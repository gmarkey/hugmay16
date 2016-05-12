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

variable "global_name" {
  default = "test-instance"
}

variable "ssh_public_key" {}
variable "ssh_private_key" {}

variable "preferred_ami" {
  default = "ami-fedafc9d"
}

variable "ebs_size" {
  default = 10
}

variable "instance_type" {
  default = "t2.micro"
}

/**/

resource "aws_key_pair" "demo_pair" {
  key_name   = "demo_pair_instance"
  public_key = "${var.ssh_public_key}"

  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_instance" "test-instance" {
  availability_zone           = "ap-southeast-2c"
  security_groups             = [ "${aws_security_group.allow_all.name}" ]
  ami                         = "${var.preferred_ami}"
  instance_type               = "${var.instance_type}"
  key_name                    = "${aws_key_pair.demo_pair.key_name}"
  associate_public_ip_address = false
  monitoring                  = false
  ebs_optimized               = false

  root_block_device = {
    volume_type = "gp2"
    volume_size = "${var.ebs_size}"
  }

  tags = {
    Name = "test-instance"
  }

  lifecycle = {
    create_before_destroy = true
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Defaults:%wheel !requiretty' | sudo tee -a /etc/sudoers"
    ]

    connection = {
      user = "centos"
      private_key = "${file(var.ssh_private_key)}"
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
  value = "${aws_instance.test-instance.public_ip}"
}
