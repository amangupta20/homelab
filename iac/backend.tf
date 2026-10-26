# State backend: one bucket in Garage, running on the TrueNAS VM.
#
# Garage does not implement S3 conditional writes (If-Match / If-None-Match), so
# OpenTofu's native lockfile cannot be used and `use_lockfile` stays off. There
# is no atomic lock: exactly one checkout may run `tofu apply`, and its plan is
# pasted into the pull request first. See iac/README.md.
#
# No credentials here. The S3 backend reads AWS_ACCESS_KEY_ID and
# AWS_SECRET_ACCESS_KEY from the environment, exported by the same wrapper that
# logs into OpenBao for the Xen Orchestra token.
#
# The address below restates what inventory/network.md owns — a backend block
# cannot interpolate variables, so this one value lives in both places.
terraform {
  backend "s3" {
    bucket = "homelab-tofu-state"
    key    = "xcp-ng/terraform.tfstate"
    region = "garage"

    endpoints = {
      s3 = "http://10.22.33.160:30188"
    }

    use_lockfile                = false
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
