# One network for this account. The address range is owned by inventory/network.md.
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "homelab"
  dns_label      = "homelab"
  cidr_blocks    = ["10.40.0.0/16"]
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "homelab"
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# The only inbound port is Tailscale's. Home is behind CGNAT and cannot accept a
# connection, so without this port traffic between home and this machine would
# stay on Tailscale's slower relays. Tailscale's WireGuard traffic is authenticated.
# A new network's default security list allows SSH from anywhere, so the subnet
# below uses this list instead.
resource "oci_core_security_list" "tailscale_only" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "tailscale-only"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17" # UDP

    udp_options {
      min = 41641
      max = 41641
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  display_name      = "public"
  dns_label         = "public"
  cidr_block        = "10.40.1.0/24"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.tailscale_only.id]
}
