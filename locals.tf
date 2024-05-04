locals {
  name = "${var.project}-${var.environment}"
  time = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
}
locals {
  commontag = var.common_tags
}
locals {
  
  privatesubnet = data.aws_ssm_parameter.private_subnet_ids.value
  
}
locals {

  catalogue_sg = data.aws_ssm_parameter.catalogue_sg_id.value
}

