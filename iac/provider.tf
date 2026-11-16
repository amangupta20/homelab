terraform {
  required_version = ">= 1.10"

  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.40"
    }
  }
}

# Login comes from the environment, set by run.sh from OpenBao: XOA_URL,
# XOA_TOKEN, and XOA_INSECURE because Xen Orchestra's certificate is
# self-signed (CN=xo-ce, read 2026-11-16).
provider "xenorchestra" {}
