# IaC — notes

When the claims in `README.md` (the Xen Orchestra root) were tested, and the
history behind its current state.

## Tested

- **First run, 2026-11-16, with no resources yet:** `./run.sh init` reached B2
  and `./run.sh plan` reached Xen Orchestra and reported no changes. That was
  also the backend's first use against the real bucket.
- **B2 has no conditional write:** it answered OpenTofu's conditional write
  with `501 NotImplemented`, tested 2026-11-04.
- **The short plan for pull requests:** the `grep` in "Plans in pull requests"
  ran against a scratch config on 2026-11-05; attribute values did not appear.
- **Debian's checksums:** `SHA512SUMS` is served over HTTPS with no signature
  file next to it, checked 2026-11-16.
- **Xen Orchestra's certificate:** self-signed, `CN=xo-ce`, read 2026-11-16.

## History

- `cache-1` was built 2026-11-16 (`agents/journal/2026-11-16-build-cache-1.md`)
  and `proxy-1` 2026-11-18 (`agents/journal/2026-11-18-build-proxy-1-traefik.md`).
- The template `debian-13-cloud-20261111-2659` was made 2026-11-16
  (`agents/journal/2026-11-16-debian-13-template.md`). The owner chose
  `Local storage` for it that day.
- The state moved to B2 on 2026-11-16, the owner's choice, as was Garage
  never changing `run.sh`'s exit code. Until then this backend pointed at a
  Garage bucket that was never created, so no state was lost by the move.
