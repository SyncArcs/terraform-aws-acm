provider "aws" {
  region = "us-east-1"
}

module "acm" {
  source                    = "./../../"
  name                      = "certificate"
  environment               = "test"
  validate_certificate      = false
  domain_name               = "syncarcs.com"
  subject_alternative_names = ["SyncArcs"]
  validation_method         = "EMAIL"
}
