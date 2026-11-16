# cache-1: the package and image cache (plans/package-and-image-cache.md), the
# first home VM built from code (plans/home-overhaul.md, step B).
#
# OpenTofu owns the VM's shape; cloud-init sets its address, hostname and first
# SSH key once, at first boot; Ansible does everything after that.

data "xenorchestra_template" "debian_13" {
  name_label = "debian-13-cloud-20261111-2659" # iac/README.md, "VM template"
}

data "xenorchestra_sr" "nvme" {
  name_label = "Nvme"
}

data "xenorchestra_network" "lan" {
  name_label = "Pool-wide network associated with eth0"
}

locals {
  cache = {
    hostname = "cache-1"
    address  = "10.22.33.137" # inventory/network.md
    # Fixed, locally administered MAC address, so the network configuration
    # below can match the interface by it instead of guessing its name.
    mac = "02:22:33:00:01:37"
  }
  lan = {
    prefix  = 24
    gateway = "10.22.33.1" # the home router (inventory/network.md)
    dns     = ["10.22.33.1"]
  }
}

resource "xenorchestra_vm" "cache" {
  name_label       = local.cache.hostname
  name_description = "Package and image cache (Artifact Keeper). Built by OpenTofu: iac/cache-vm.tf."
  template         = data.xenorchestra_template.debian_13.id
  tags             = ["managed-by-opentofu", "cache"]

  cpus       = 2
  memory_max = 2 * 1024 * 1024 * 1024 # 2 GiB; Artifact Keeper idled at ~185 MB in the local test

  hvm_boot_firmware = "uefi"
  secure_boot       = true # the template's clone booted with Secure Boot on (2026-11-16)
  auto_poweron      = true

  network {
    network_id  = data.xenorchestra_network.lan.id
    mac_address = local.cache.mac
  }

  # 100 GB provisional: the system plus PostgreSQL with room for the cache cap; the plan ("How much disk") still sets the real budget after step 0.
  disk {
    sr_id      = data.xenorchestra_sr.nvme.id
    name_label = "${local.cache.hostname}-root"
    size       = 100 * 1000 * 1000 * 1000
  }

  cloud_config = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname       = local.cache.hostname
    ssh_public_key = var.vm_ssh_public_key
  })

  cloud_network_config = templatefile("${path.module}/cloud-init/network-v1.yaml.tftpl", {
    mac     = local.cache.mac
    address = "${local.cache.address}/${local.lan.prefix}"
    gateway = local.lan.gateway
    dns     = local.lan.dns
  })

  # The drive only carries first-boot settings; nothing reads it afterwards.
  destroy_cloud_config_vdi_after_boot = true
}
