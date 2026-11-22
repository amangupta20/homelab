# agent-1: the agent VM (agents/plans/home-overhaul.md, step B0), where agents and the
# owner's AI-assisted development run around the clock. Built the same way as cache-1
# (cache-vm.tf, whose template, storage, network and LAN settings it reuses): OpenTofu
# owns the VM's shape, cloud-init sets its address and first key once, Ansible does the
# rest.

locals {
  agent = {
    hostname = "agent-1"
    address  = "10.22.33.139" # lab/inventory/network.md
    mac      = "02:22:33:00:01:39"
  }
}

resource "xenorchestra_vm" "agent" {
  name_label       = local.agent.hostname
  name_description = "Agent VM: coding agents, Orca workers, test containers. Built by OpenTofu: iac/agent-vm.tf."
  template         = data.xenorchestra_template.debian_13.id
  tags             = ["managed-by-opentofu", "agent"]

  # 4 vCPUs (plan, owner 2026-11-22).
  cpus = 4
  # Dynamic memory 256 MiB to 8 GiB, with a 10 GiB static maximum (owner, 2026-11-23).
  # Provider v0.41.2 reads the dynamic maximum here and writes both maxima on VM
  # updates. Verify the 10 GiB static maximum in Xen Orchestra after any such update.
  # The 128 MiB static minimum comes from the template.
  memory_max = 8192 * 1024 * 1024
  memory_min = 256 * 1024 * 1024
  vga        = "std"

  hvm_boot_firmware = "uefi"
  secure_boot       = true
  auto_poweron      = true

  network {
    network_id  = data.xenorchestra_network.lan.id
    mac_address = local.agent.mac
  }

  # 150 GB (owner, 2026-11-23) rounded up to whole 2 MiB blocks.
  disk {
    sr_id      = data.xenorchestra_sr.nvme.id
    name_label = "${local.agent.hostname}-root"
    size       = 71526 * 2 * 1024 * 1024
  }

  cloud_config = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    hostname       = local.agent.hostname
    ssh_public_key = var.vm_ssh_public_key
  })

  cloud_network_config = templatefile("${path.module}/cloud-init/network-v1.yaml.tftpl", {
    mac     = local.agent.mac
    address = "${local.agent.address}/${local.lan.prefix}"
    gateway = local.lan.gateway
    dns     = local.lan.dns
  })

  power_state                         = "Running"
  destroy_cloud_config_vdi_after_boot = true
}
