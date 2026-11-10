# Authentik is the single sign-on provider

Decided: 2026-11-10 by the owner, in a working session; written up by an
agent. Status: proposed, for the owner to confirm in review.

## Why

The owner chose Authentik for step 4 of `plans/vps-foundations.md`. The
earlier note against it (`decisions/open-questions.md`, "Foundations": tried
around 2024 and found too heavy) dated from early in learning self-hosting,
and was never final. Since version 2025.10 it no longer needs Redis, and its
database goes on the shared Postgres cluster (`plans/shared-postgres.md`), so
the stack is two containers. The lighter candidates (Authelia, Pocket ID,
Kanidm) were not compared.

## Cost / what this rules out

- Authentik is generally the heaviest of the four candidates in memory and
  moving parts (general knowledge, not compared here); its RAM use on the VPS
  has not been measured yet.
- It is the most exposed service on the VPS, so it gets no Docker socket and
  its admin interface answers on the tailnet only
  (`apps/vps/authentik/README.md`).
- SSO depends on pigsty-1 being up, because its database is there.
- Forward-auth for apps without their own sign-in can use Authentik's
  embedded outpost through Traefik; the wider forward-auth question for the
  home edge stays open (`ideas/edge-and-security-layers.md`, "Sign-in").

## Where it lives

`apps/vps/authentik/`, `plans/vps-foundations.md`.
