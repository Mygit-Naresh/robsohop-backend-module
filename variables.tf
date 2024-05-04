variable "environment" {
  
}
variable "project" {
  
}
variable "common_tags" {
  type = map(string)
  default = {
    Createdby   = "Terraform",
    Costcenter  = "FIN-005-HYD-CLOUD-AWS",
    Admin_email = "admin.roboshop@gmail.com"
  }
}
variable "tags" {
  
}

variable "private_subnet_id" {
  
}
variable "name" {
  
}
variable "ami" {
  
}

variable "vpc_security_group_ids" {
  
}

variable "ami_user" {
  
}
variable "ami_password" {
  
}

variable "zone_id" {
  default = "Z101265833JA5X90XBKK8"
}
variable "zone_name" {
  default = "eternaltrainings.online"  
}
variable "instance_type" {
  
}

variable "priority" {
  
}
variable "app_listener_arn" {
  
}
variable "port" {
  
}