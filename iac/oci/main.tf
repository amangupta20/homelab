# Deliberately creates nothing yet. A first plan and apply prove the whole chain
# (OpenBao, API key, policy, state bucket, encryption) with nothing at risk.
data "oci_identity_availability_domains" "this" {
  compartment_id = var.compartment_ocid
}

output "availability_domains" {
  description = "Availability domain names visible to this user."
  value       = data.oci_identity_availability_domains.this.availability_domains[*].name
}
