data "aws_region" "this" {}
data "aws_caller_identity" "current" {}

locals {
  region               = data.aws_region.this.region
  current_arn          = provider::aws::arn_parse(data.aws_caller_identity.current.arn)
  current_arn_resource = startswith(local.current_arn.resource, "assumed-role/") ? "role/${split("/", local.current_arn.resource)[1]}" : local.current_arn.resource
  self_arn             = "arn:${local.current_arn.partition}:iam::${local.current_arn.account_id}:${local.current_arn_resource}"
}
