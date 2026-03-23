module "logs" {
  source  = "nullstone-modules/logs/aws"
  version = "~> 0.2.0"

  name                       = local.resource_name
  tags                       = local.tags
  log_reader_type            = "role"
  log_reader_role_principals = [local.ns_agent_user_arn]
  enable_get_metrics         = true
  retention_in_days          = var.log_retention_in_days
  kms_key_arn                = aws_kms_key.this.arn
}

locals {
  log_configuration = {
    logDriver = "awslogs"
    options = {
      "awslogs-region"        = local.region
      "awslogs-group"         = module.logs.name
      "awslogs-stream-prefix" = local.block_name
    }
  }
  log_provider = "cloudwatch"
}
