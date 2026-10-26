# tflint rules for iac/. The built-in terraform ruleset catches deprecated
# syntax and invalid references; it does not need a provider plugin if
# `tflint --init` can resolve it from the registry.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
