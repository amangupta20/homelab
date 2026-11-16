# State backend for the Xen Orchestra root: the same private Backblaze B2 bucket
# as iac/oci/, under its own key. B2 stays reachable when home is down, and the
# state does not live on the machines it describes (owner, 2026-11-16). A second,
# encrypted copy goes to Garage at home after each change (lib/state-copy.sh).
#
# The bucket's name is passed in at `tofu init` by run.sh, so this block is
# partial on purpose. No credentials here: run.sh reads them from OpenBao.
terraform {
  backend "s3" {
    key    = "xcp-ng/terraform.tfstate"
    region = "eu-central-003"

    endpoints = {
      s3 = "https://s3.eu-central-003.backblazeb2.com"
    }

    # B2 answers OpenTofu's conditional write with 501 NotImplemented (tested
    # 2026-11-04), so there is no lock: the one-writer rule in README.md is the
    # only protection.
    use_lockfile                = false
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  # State and saved plans hold secrets and leave this machine, so they are
  # encrypted before upload, with the same passphrase as iac/oci/. `enforced`
  # refuses to write them unencrypted.
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
