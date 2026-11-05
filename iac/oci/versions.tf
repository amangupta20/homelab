# OpenTofu root for Oracle Cloud Infrastructure (OCI). See README.md.
#
# Holds no credentials and no tenancy details: run.sh reads them from OpenBao.
# The state bucket's name is also passed in at `tofu init`, so this backend block
# is partial on purpose.
terraform {
  required_version = ">= 1.10"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.11"
    }
  }

  backend "s3" {
    key    = "oci/terraform.tfstate"
    region = "eu-central-003"

    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }

    # B2 answers OpenTofu's conditional write with 501 NotImplemented (tested
    # 2026-11-04), so there is no lock: the one-writer rule in iac/README.md is
    # the only protection.
    use_lockfile                = false
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  # State and saved plans hold secrets and leave this machine, so they are
  # encrypted before upload. `enforced` refuses to write them unencrypted.
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  user_ocid    = var.user_ocid
  fingerprint  = var.fingerprint
  private_key  = var.private_key
  region       = var.region
}
