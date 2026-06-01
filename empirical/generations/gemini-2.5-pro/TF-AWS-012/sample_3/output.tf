locals {
  site_name = "static-site-${random_pet.site.id}"
  tags = {
    Terraform   = "true"
    Project     = "StaticSite"
    Environment = "Production"
  }
}

resource "random_pet" "site" {
  length = 2
}

resource "aws