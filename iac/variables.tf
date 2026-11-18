variable "state_passphrase" {
  description = "Passphrase that encrypts state and saved plans. Losing it loses the state."
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "Public half of the homelab VM key (kv/general/vm-ssh), given to every VM at first boot."
  type        = string
}

variable "lab_zone" {
  description = "The lab's DNS zone on Cloudflare (kv/general/cloudflare, field zone). Kept out of this public repo."
  type        = string
}
