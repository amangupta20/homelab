terraform {
  required_version = ">= 1.10"

  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.40"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Login comes from the environment, set by run.sh from OpenBao: XOA_URL,
# XOA_TOKEN, and XOA_INSECURE because Xen Orchestra's certificate is
# self-signed (CN=xo-ce, read 2026-11-16).
provider "xenorchestra" {}

# The token comes from the environment, set by run.sh from OpenBao
# (kv/general/cloudflare, field zonedns). It may read the zone and edit its
# DNS records, nothing else (token verify and zone listing, 2026-11-18).
provider "cloudflare" {}
