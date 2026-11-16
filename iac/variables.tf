variable "state_passphrase" {
  description = "Passphrase that encrypts state and saved plans. Losing it loses the state."
  type        = string
  sensitive   = true
}
