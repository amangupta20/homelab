terraform {
  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.40"
    }
  }
}

# Creds via env: XOA_URL, XOA_TOKEN
# provider "xenorchestra" {}
