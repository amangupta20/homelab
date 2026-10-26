terraform {
  required_version = ">= 1.10"

  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.40"
    }
  }
}

# Creds via env: XOA_URL, XOA_TOKEN
# provider "xenorchestra" {}
