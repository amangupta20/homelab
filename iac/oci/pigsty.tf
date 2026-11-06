# The Pigsty node in phase 1 of plans/shared-postgres.md. It uses 3 of the 4 free
# Ampere OCPUs, 18 of the 24 GB and 150 of the 200 GB of disk; the rest is kept for
# Pangolin. To stay free, the shape must stay on Ampere and the disk total at 200 GB.
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"

  # Leaves out the Minimal images.
  filter {
    name   = "display_name"
    values = ["^Canonical-Ubuntu-24\\.04-aarch64-.*"]
    regex  = true
  }
}

resource "oci_core_instance" "pigsty" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
  display_name        = "pigsty-1"
  shape               = "VM.Standard.A1.Flex"

  # Keep the boot volume if the instance is ever terminated: it holds the database.
  preserve_boot_volume = true

  shape_config {
    ocpus         = 3
    memory_in_gbs = 18
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 150
    # 10 is "Balanced". Higher performance levels cost money.
    boot_volume_vpus_per_gb = 10
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    hostname_label   = "pigsty-1"
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.yaml.tftpl", {
      hostname           = "pigsty-1"
      tailscale_auth_key = var.tailscale_auth_key
    }))
  }

  lifecycle {
    prevent_destroy = true
    # Without this, a newer Ubuntu image or a rotated auth key would plan to rebuild
    # the machine. Both only matter at first boot.
    ignore_changes = [metadata, source_details[0].source_id]
  }
}

output "pigsty_instance_id" {
  description = "OCID of the Pigsty node."
  value       = oci_core_instance.pigsty.id
}
