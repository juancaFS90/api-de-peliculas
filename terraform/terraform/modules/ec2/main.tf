data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu oficial)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]
  user_data              = var.user_data

  # LabInstanceProfile: necesario en entornos AWS Academy/Learner Lab para
  # que las instancias puedan leer parámetros de SSM sin credenciales explícitas.
  # En una cuenta AWS propia, reemplazar con un IAM role que tenga:
  # ssm:GetParameter sobre /${project_tag}/*
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name    = var.name
    Project = var.project_tag
  }
}
