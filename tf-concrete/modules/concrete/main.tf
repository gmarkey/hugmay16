variable "global_name" {}
variable "ssh_public_key" {}
variable "iam_profile_name" {}
variable "terraform_url" {}
variable "git_repo" {}
variable "test_script" {}

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
  key_name   = "demo_pair_concrete"
  public_key = "${var.ssh_public_key}"
  
  lifecycle = {
    create_before_destroy = true
  }

}

resource "aws_instance" "concrete" {
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
    Name = "concrete"
  }

  lifecycle = {
    create_before_destroy = true
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install epel-release",
      "sudo yum -y install npm git unzip mongodb-server",
      "sudo npm install -g concrete",
      "sudo systemctl start mongod",
      "curl -Lo terraform.zip ${var.terraform_url}",
      "sudo unzip terraform.zip -d /usr/sbin",
      "git clone ${var.git_repo} repo",
      "cd repo && git config --add concrete.runner 'bash -c ${var.test_script}' && concrete . & disown",
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

output "concrete_url" {
  value = "http://${aws_instance.concrete.public_ip}:4567"
}
