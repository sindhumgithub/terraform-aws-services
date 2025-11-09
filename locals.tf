locals {
  private_subnet_id = split(",", data.aws_ssm_parameter.private_subnet_id.value)[0]
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_id.value)
  sg_id = data.aws_ssm_parameter.sg_id.value
  common_name_suffix = "${var.project_name}-${var.environment}"
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  ami_id = data.aws_ami.ami.id
  backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value


  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Terraform   = "true"
    Service     = var.service_name
  }
}