provider "aws" {
  region = "us-east-1"
}

locals {
  domain = ""
}

module "acm" {
  source                    = "./../../"
  name                      = "certificate"
  environment               = "test"
  domain_name               = "SyncArcs.com"
  subject_alternative_names = ["*.${local.domain}", "www.${local.domain}"]
}
