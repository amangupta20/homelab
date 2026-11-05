# All of these are set by run.sh from OpenBao, as TF_VAR_* variables.

variable "tenancy_ocid" {
  description = "OCID (Oracle Cloud ID) of the tenancy."
  type        = string
}

variable "user_ocid" {
  description = "OCID of the IAM user OpenTofu signs in as."
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of that user's API key."
  type        = string
}

variable "private_key" {
  description = "PEM private key of that user's API key."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI region identifier."
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the compartment OpenTofu manages. Everything it creates goes here."
  type        = string
}

variable "state_passphrase" {
  description = "Passphrase that encrypts state and saved plans. Losing it loses the state."
  type        = string
  sensitive   = true
}
