# proxy-1: the home reverse proxy, Traefik (agents/plans/home-overhaul.md, step B4a).
# Built the same way as cache-1 (cache-vm.tf, whose template, storage, network
# and LAN settings it reuses): OpenTofu owns the VM's shape and its DNS name,
# cloud-init sets its address and first key once, Ansible does the rest
# (ansible/proxy.yml).

locals {
  proxy = {
    hostname = "proxy-1"
    address  = "10.22.33.138" # inventory/network.md
    mac      = "02:22:33:00:01:38"
  }
}

resource "xenorchestra_vm" "proxy" {
  name_label       = local.proxy.hostname
  name_description = "Home reverse proxy (Traefik). Built by OpenTofu: iac/proxy-vm.tf."
  template         = data.xenorchestra_template.debian_13.id
  tags             = ["managed-by-opentofu", "proxy"]

  # Sizing proposed 2026-11-18 and accepted by the owner going ahead with it:
  # Traefik alone, a few routes. Raised if it runs near the top.
  cpus       = 1
  memory_max = 1024 * 1024 * 1024
  memory_min = 256 * 1024 * 1024
  vga        = "std"

  hvm_boot_firmware = "uefi"
  secure_boot       = true
  auto_poweron      = true

  network {
    network_id  = data.xenorchestra_network.lan.id
    mac_address = local.proxy.mac
  }

  # 10 GB in whole 2 MiB blocks (see the cache-1 disk for why).
  disk {
    sr_id      = data.xenorchestra_sr.nvme.id
    name_label = "${local.proxy.hostname}-root"
    size       = 4769 * 2 * 1024 * 1024
  }

  cloud_config = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname       = local.proxy.hostname
    ssh_public_key = var.vm_ssh_public_key
  })

  cloud_network_config = templatefile("${path.module}/cloud-init/network-v1.yaml.tftpl", {
    mac     = local.proxy.mac
    address = "${local.proxy.address}/${local.lan.prefix}"
    gateway = local.lan.gateway
    dns     = local.lan.dns
  })

  power_state                         = "Running"
  destroy_cloud_config_vdi_after_boot = true
}

# Internal names: one wildcard record, *.home.<zone>, pointing at proxy-1's
# LAN address. It is public so any resolver that forwards to the internet
# answers it; only the LAN and the tailnet (through the router's subnet route)
# can reach the address. DNS only, never proxied: Cloudflare cannot reach it.
data "cloudflare_zone" "lab" {
  filter = {
    name = var.lab_zone
  }
}

resource "cloudflare_dns_record" "home_wildcard" {
  zone_id = data.cloudflare_zone.lab.zone_id
  name    = "*.home.${var.lab_zone}"
  type    = "A"
  content = local.proxy.address
  ttl     = 300
  proxied = false
  comment = "Home reverse proxy proxy-1. Managed by OpenTofu (iac/proxy-vm.tf)."
}
