module "service_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"
  name   = var.name

  instance_type          = var.instance_type
  ami                    =  var.ami               #data.aws_ami.centos.image_id
  vpc_security_group_ids = [var.vpc_security_group_ids] #data.aws_ssm_parameter.catalogue_sg_id.value
  subnet_id              =  var.private_subnet_id    #element(split(",",var.private_subnet_id ), 0)#data.aws_ssm_parameter.private_subnet_ids.value

  tags = merge(var.common_tags,
    {
      Name             = "${var.project}-${var.environment}-${var.tags.service}"
      Create_date_time = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  })

}
 
resource "null_resource" "service_config" {
 
  triggers = {
    instance_id = module.service_instance.id
  }

  
    connection {
    type     = "ssh"
    user     = var.ami_user   #data.aws_ssm_parameter.ami_user.value 
    password = var.ami_password  #data.aws_ssm_parameter.ami_password.value
    host     = module.service_instance.private_ip
  }
  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
       
       "sudo chmod +x /tmp/bootstrap.sh",
       "sh /tmp/bootstrap.sh ${var.tags.service} ${var.environment}"
  
  ]
  }
}
resource "aws_ec2_instance_state" "service_stop" {
  instance_id = module.service_instance.id
  state       = "stopped"
  depends_on = [ null_resource.service_config ]
}
resource "aws_ami_from_instance" "service_ami" {
  name               = "terraform-${var.tags.service}-AMI"
  source_instance_id =  module.service_instance.id
   depends_on = [ aws_ec2_instance_state.service_stop ]

  tags = merge(var.common_tags,  
    {
     Name = "${var.project}-${var.environment}-${var.tags.service}-AMI"   
  })
}
resource "null_resource" "service_terminate" {

 triggers = {
    instance_id =  module.service_instance.id
}

  provisioner "local-exec" {
   
       
      command =  "aws ec2 terminate-instances --instance-ids ${module.service_instance.id}"
  }
      depends_on = [ aws_ami_from_instance.service_ami ]
}
  
resource "aws_launch_template" "service_lt" {
  name_prefix   = "${var.tags.service}-LT"
  image_id      = aws_ami_from_instance.service_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [var.vpc_security_group_ids]         #[data.aws_ssm_parameter.service_sg_id.value]
  
  
  tags = merge(var.common_tags,
    {
      Name             = "${var.project}-${var.environment}-${var.tags.service}-Launchtemplate"
      Create_date_time = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  })
  
}
resource "aws_autoscaling_group" "asg-service" {
  name                      = "ASG-${var.tags.service}"
  max_size                  = 4
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          =  2
  vpc_zone_identifier       = split(",",var.private_subnet_id)
  launch_template {
    id      = aws_launch_template.service_lt.id
    version =  "$Latest"
  }
    
   instance_refresh {
      strategy = "Rolling"
      preferences  {
        min_healthy_percentage = 50
      }

      triggers = [ "launch_template" ]
       
   }

  tag {
    key                 = "Name"
    value               = "${var.tags.service}-autoscale"
    propagate_at_launch = true
  }

}

resource "aws_lb_listener_rule" "app-lb-rule" {
  listener_arn = var.app_listener_arn #data.aws_ssm_parameter.app-lb-listener_arn.value
  priority     = var.priority
  

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg.arn
  }

  

  condition {
    host_header {
      values = ["${var.tags.service}.app-${var.environment}.${var.zone_name}"]
    }
  }


tags = merge(var.common_tags,
    {
      Name             = "${var.project}-${var.environment}-${var.tags.service}-rule"
      Create_date_time = formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())
  })
}
resource "aws_lb_target_group" "service_tg" { // Target Group service
 name     = "${var.project}-${var.environment}-${var.tags.service}-tg"
 port     = var.port
 protocol = "HTTP"
 vpc_id   = data.aws_ssm_parameter.vpc_id.value
 deregistration_delay = 60
 
 health_check {
    path                = "/health"
    port                = 80
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-499"
    interval = 10
    
  } 

}
 
resource "aws_autoscaling_attachment" "lb_attachment_to_tg" {
  autoscaling_group_name = aws_autoscaling_group.asg-service.name
  lb_target_group_arn    = aws_lb_target_group.service_tg.arn
}

resource "aws_autoscaling_policy" "avg_cpu_scaling_policy" {
 
  name                   = "avg-cpu-scling-policy"
  policy_type = "TargetTrackingScaling" 
  autoscaling_group_name = aws_autoscaling_group.asg-service.name
  estimated_instance_warmup = 60
  # CPU Utilization is above 50
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }  
}
# resource "aws_autoscaling_policy" "example" {
#   autoscaling_group_name = aws_autoscaling_group.asg-service.name
#   name                   = "service-ASG"
#   policy_type            = "PredictiveScaling"
#   predictive_scaling_configuration {
#     metric_specification {
#       target_value = 50
#       predefined_load_metric_specification {
#         predefined_metric_type = "ASGTotalCPUUtilization"
#         resource_label         = "app/my-alb/778d41231b141a0f/targetgroup/my-alb-target-group/943f017f100becff"
#       }
#       customized_scaling_metric_specification {
#         metric_data_queries {
#           id = "scaling"
#           metric_stat {
#             metric {
#               metric_name = "CPUUtilization"
#               namespace   = "AWS/EC2"
#               dimensions {
#                 name  = aws_autoscaling_group.asg-service.name
#                 value = "my-test-asg"
#               }
#             }
#             stat = "Average"
#           }
#         }
#       }
#     }
#   }
# }

