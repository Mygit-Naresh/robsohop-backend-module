data "aws_ami" "centos" {
  most_recent = true
  owners      = ["973714476881"]
  filter {
    name   = "name"
    values = ["Centos-8-*"]
  }
}
data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/${var.project}/${var.environment}/private_subnet_ids"
}
data "aws_ssm_parameter" "catalogue_sg_id" {
  name = "/${var.project}/${var.environment}/catalogue_sg_id"
}
data "aws_ssm_parameter" "ami_user" {
    name = "/${var.project}/${var.environment}/ami_user"
}
data "aws_ssm_parameter" "ami_password" {
    name = "/${var.project}/${var.environment}/ami_password"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/vpc_id"
}
data "aws_ssm_parameter" "app-lb-listener_arn" {
  name = "/${var.project}/${var.environment}/app-lb-listener_arn"
}

