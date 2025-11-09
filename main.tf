#1. ec2 instnace creation
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [local.sg_id]
  subnet_id              = local.private_subnet_id

  tags = merge(
    local.common_tags,
    { 
        Name = "${var.project_name}-${var.environment}-${var.service_name}" 
    }
  )
}

#2. configure ec2 instance.
resource "terraform_data" "provisioner" {
  triggers_replace = [
    aws_instance.this.id  # Re-run if instance is replaced
  ]

  connection {
    type     = "ssh"
    user     = var.ssh_user
    password = var.ssh_password
    host     = aws_instance.this.private_ip
    timeout  = "5m"
  }

  # Copy the correct script
  provisioner "file" {
    source      =   "services.sh"
    destination = "/tmp/services.sh"
  }

  # Execute it
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/services.sh",
      "sudo sh /tmp/services.sh ${var.service_name} ${var.environment}"
    ]
  }
}



#3. Stop EC2 Instance to take AMI ID
resource "aws_ec2_instance_state" "this" {
  instance_id = aws_instance.this.id
  state       = "stopped"
  depends_on = [terraform_data.provisioner]
}


# 4. Terraform code to take AMI from stopped Instance.
resource "aws_ami_from_instance" "this" {
  name               = "${local.common_name_suffix}-${var.service_name}-ami"
  source_instance_id = aws_instance.this.id
  depends_on = [aws_ec2_instance_state.this]
    tags = merge (
    local.common_tags,
    {
      Name = "${local.common_name_suffix}-${var.service_name}"
    }
  )
}

# 5. target group creation.
resource "aws_lb_target_group" "this" {
  name     = "${local.common_name_suffix}-${var.service_name}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 60

  health_check {
    healthy_threshold   = 2
    interval            = var.health_check_interval
    matcher             = "200-299"
    path                = "/health"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 2
    unhealthy_threshold = 2
  }
}

# 6. terraform code to create launch template.
resource "aws_launch_template" "this" {
  name = "${local.common_name_suffix}-${var.service_name}"
  image_id = local.ami_id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = var.instance_type
  vpc_security_group_ids = [local.sg_id]

  # Tags for Instances
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name    = "${local.common_name_suffix}-${var.service_name}"
        Service = var.service_name
      }
    )
  }

  # Tags for Volumes
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name    = "${local.common_name_suffix}-${var.service_name}"
        Service = var.service_name
      }
    )
  }

  # Tags for Launch Template itself
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.common_name_suffix}-${var.service_name}"
      Service = var.service_name
    }
  )
}


#7. Autoscaling code 
resource "aws_autoscaling_group" "this" {
  name                      = "${local.common_name_suffix}-${var.service_name}"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns = [aws_lb_target_group.this.arn]
  dynamic "tag" {  # We will get the iterator with name as tag
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.common_name_suffix}-${var.service_name}"
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  timeouts {
    delete = "15m"
  }
}


#8. Autoscaling policy code.
resource "aws_autoscaling_policy" "this" {
  autoscaling_group_name = aws_autoscaling_group.this.name
  name                   = "${local.common_name_suffix}-${var.service_name}"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

#9. Load Balancer Rule
resource "aws_lb_listener_rule" "this" {
  listener_arn = local.backend_alb_listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = ["${var.service_name}.backend-alb-${var.environment}.${var.domain_name}"]
    }
  }
}