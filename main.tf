## Managed By : SyncArcs
## Description : This Script is used to create Transfer Server, Transfer User And label.
## Copyright @ SyncArcs. All Right Reserved.

module "labels" {
  source      = "git::https://github.com/SyncArcs/terraform-aws-labels.git?ref=v1.0.0"
  name        = var.name
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
  repository  = var.repository
}

## Sanitize and Validate Domain Names
locals {
  sanitized_domain_name = trim(var.domain_name, ".")

  sanitized_subject_alternative_names = [
    for domain in var.subject_alternative_names : trim(domain, ".")
    if length(trim(domain, ".")) <= 253 && length(trim(domain, ".")) >= 1
    && can(regex("^(\\*\\.)?(((?!-)[A-Za-z0-9-]{0,62}[A-Za-z0-9])\\.)+((?!-)[A-Za-z0-9-]{1,62}[A-Za-z0-9])$", trim(domain, ".")))
  ]
}

## Import Certificate (if enabled)
resource "aws_acm_certificate" "import-cert" {
  count = var.enable && var.import_certificate ? 1 : 0

  private_key       = file(var.private_key)
  certificate_body  = file(var.certificate_body)
  certificate_chain = file(var.certificate_chain)
  tags              = module.labels.tags

  dynamic "validation_option" {
    for_each = var.validation_option

    content {
      domain_name       = try(trim(validation_option.value["domain_name"], "."), validation_option.key)
      validation_domain = trim(validation_option.value["validation_domain"], ".")
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

## Create ACM Certificate (if enabled)
resource "aws_acm_certificate" "cert" {
  count = var.enable && var.enable_aws_certificate ? 1 : 0

  domain_name               = local.sanitized_domain_name
  validation_method         = var.validation_method
  subject_alternative_names = local.sanitized_subject_alternative_names
  tags                      = module.labels.tags

  dynamic "validation_option" {
    for_each = var.validation_option

    content {
      domain_name       = try(trim(validation_option.value["domain_name"], "."), validation_option.key)
      validation_domain = trim(validation_option.value["validation_domain"], ".")
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

## Validate ACM Certificate (if enabled)
resource "aws_acm_certificate_validation" "cert" {
  count                   = var.enable && var.validate_certificate ? 1 : 0
  certificate_arn         = join("", aws_acm_certificate.cert[*].arn)
  validation_record_fqdns = flatten([aws_route53_record.default[*].fqdn, var.validation_record_fqdns])
}

## Fetch Route53 Zone (if DNS validation is enabled)
data "aws_route53_zone" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  name         = local.sanitized_domain_name
  private_zone = var.private_zone
}

## Create Route53 Validation Records (if DNS validation is enabled)
resource "aws_route53_record" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  zone_id         = join("", data.aws_route53_zone.default[*].zone_id)
  ttl             = var.ttl
  allow_overwrite = var.allow_overwrite
  name            = join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_name)
  type            = join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_type)
  records         = [join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_value)]
}

## Validate ACM Certificate with Route53 (if DNS validation is enabled)
resource "aws_acm_certificate_validation" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  certificate_arn         = join("", aws_acm_certificate.cert[*].arn)
  validation_record_fqdns = aws_route53_record.default[*].fqdn
}


