---
type: idea
status: "researched"
verified: "no (research only; no tool was run)"
tags:
  - idea
  - opentofu
  - ansible
---

# A web UI for OpenTofu and Ansible

**Status:** researched
**In one line:** a self-hosted web page to see what OpenTofu and Ansible manage and
what they last did, and possibly to start runs from it.
**Why try it:** infrastructure as code is only visible from a terminal today. A UI
would make it easy to look at, keep a history of runs, and, if runs go through it,
make the one-writer rule in `iac/README.md` easier to keep.
**Needs first:** more to look at. `iac/oci/` has applied once (`pigsty-1`, 2026-11-06) and `ansible/base.yml` exists; `iac/` (Xen Orchestra) has not.

## Design sketch

Two kinds of tool, and the choice is mostly between them:

- **See only:** records or displays results, holds no keys that can change anything.
- **Run and see:** starts runs itself, so it has to hold credentials.

| Tool | Kind | Covers | Notes |
|---|---|---|---|
| ARA | see | Ansible | Records runs through a callback plugin. Can use local SQLite with no server. GPL-3.0 |
| Terraboard | see | state files | No authentication of its own, needs PostgreSQL, README does not mention OpenTofu, compatibility table stops at Terraform 0.14.10. Poor fit |
| Rover | see | resource graph | Last push July 2025. OpenTofu support unverified |
| Semaphore UI | run | OpenTofu, Terraform, Ansible, scripts | The only one found that covers both tools. MIT. OpenBao integration, built-in state and project runners are Pro (paid) |
| AWX | run | Ansible | Avoid for now: last release July 2024, releases paused during a refactor |
| Rundeck | run | any job | General job runner, not built around either tool |
| Terrakube, OTF | run | OpenTofu or Terraform | Terraform Enterprise alternatives. Heavy here, and would likely take over storing state. OpenTofu support not confirmed |
| Atlantis | run | OpenTofu or Terraform | Plan and apply from pull request comments. Not a dashboard, and comments would publish plans on this public repo |

Leaning, not decided: `tofu state list`, `show` and `graph` for OpenTofu (no server,
and they handle state encryption), ARA once playbooks exist, and Semaphore only if
one UI for both, or starting runs away from the workstation, becomes worth its costs.

## Risks and costs

- **Encrypted state:** the Oracle Cloud state in B2 is ciphertext, so a viewer that
  reads the bucket directly should see nothing useful unless it supports OpenTofu
  encryption. Inferred, not tested; no docs read mention it. Weakening encryption to
  get a dashboard is not worth it.
- **A run-and-see tool is a high-value target:** it holds keys that can change
  infrastructure, on a machine that is always on. Today those keys only reach the
  workstation during a run.
- **Rebuild dependency:** on the VPS it goes down with the machine it would help
  rebuild, so `iac/oci/run.sh` stays as the fallback either way.
- **Secrets on Semaphore's free tier:** they would be copied into its own store, or
  it would need a token that can read OpenBao. Either weakens keeping them only in
  OpenBao.
- **Public repo:** anything that posts plans to pull requests publishes them.

## Promote when

Any of: Ansible playbooks exist and their runs are worth reviewing; runs need to
start away from the workstation; OpenTofu runs from more than one machine. Before
choosing Semaphore, check on a throwaway instance whether it can pause between plan
and apply for approval, and whether it blocks two runs of one task at once. Neither
was confirmed. Its site also disagrees with itself on whether workflows are free.

## Sources

Researched 2026-11-05 from project sites, READMEs and the GitHub API (licences, last
push). Nothing was installed.

- Semaphore UI: <https://semaphoreui.com/>
- ARA: <https://ara.recordsansible.org/>
- Terraboard: <https://github.com/camptocamp/terraboard>
- Rover: <https://github.com/im2nguyen/rover>
- AWX: <https://github.com/ansible/awx>
- Rundeck: <https://github.com/rundeck/rundeck>
- Terrakube: <https://github.com/terrakube-io/terrakube>
- OTF: <https://github.com/leg100/otf>
- Atlantis: <https://github.com/runatlantis/atlantis>
