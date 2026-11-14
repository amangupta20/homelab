# 2026-11-14 — Clef answered through 9router but Hindsight got nothing: patch 9router

**Who:** Claude Code (Opus 5.5), asked by the owner  **Scope:** remote VPS, the `9router` container (Dokploy project `router9`) and Hindsight's reranker chain  **Mode:** write
**Task:** the owner: Hindsight's Cloudflare Clef reranker is not working; make it work  **Skill:** none

## What happened

Hindsight reranks recall results through a chain of decision models, all
reached through 9router (an AI gateway in front of several providers):
Jev (`oc/jev-1.13-free`) first, Cloudflare Clef
(`cf/@cf/cloudflare/clef-flash`) second, Perplexity's decider on OpenRouter
third, then RRF (reciprocal rank fusion, a rank merge that needs no model).
Source: the `HINDSIGHT_API_RERANKER_*` variables of the `hindsight-api`
container (`docker inspect`).

Clef was answering, but nobody downstream could read the answer. Cloudflare's
REST API wraps every result as
`{"result": {"model", "answers", "usage"}, "success", "errors", "messages"}`,
and 9router's System One handler (System One is the API that decision
models like Jev and Clef speak) forwards the upstream body untouched
(`open-sse/handlers/systemoneCore.js`, and the same code compiled into
the route the server runs). Hindsight's `typesafe` reranker, like 9router's
own dashboard test ("Provider returned no answers for this model"), reads
`answers` from the top level, so every Clef call came back empty. Seen with a
`POST /v1/systemone` to 9router from inside the `hindsight-api` container.

9router 0.5.119 was running, the newest release on npm on 2026-11-14
(`npm view 9router version`), and upstream `master` had the same code, so
updating would not have fixed it.

A first diagnosis was wrong and is recorded so nobody repeats it: calling Clef
through `/v1/chat/completions` returns `No such model clef-flash`. That route
treats it as a text model; it says nothing about whether Clef exists.

## What changed

- In the running `9router` container, `.next/server/chunks/9489.js` and
  `.next/server/app/api/v1/systemone/route.js` (the compiled route; editing
  `open-sse/` changes nothing at runtime) got one inserted statement before
  the response is forwarded: if the body has `result.answers`, forward
  `result`. Unwrapped bodies, like Jev's, are unchanged. The originals are
  kept next to them as `*.orig`. Then `docker restart 9router`.
- The fix was sent upstream with a unit test:
  [decolua/9router#5687](https://github.com/decolua/9router/pull/5687)
  (from the fork `amangupta20/9router`).

## Snapshot / backup taken

None of the VM. The two edited files were copied to `*.orig` inside the
container first; recreating the container from its image also undoes the
patch.

## How it was verified

- After the patch, `POST /v1/systemone` with `cf/@cf/cloudflare/clef-flash`
  returned `{"model":"clef-flash","answers":{…},"usage":{…}}`, the same shape
  as Jev's reply; Jev still answered.
- A recall on `aman-mem` returned results, reranking 100 candidates in 0.8 s
  (`hindsight-api` logs). Jev handled that recall, so Hindsight falling back
  to Clef was **not** exercised; only the reply shape was.
- Upstream test: the new `tests/unit/cloudflare-systemone.test.js` fails
  without the fix and passes with it; all 31 System One tests pass.

## Still open

- **The patch is not durable.** It lives in the container's writable layer:
  a Dokploy redeploy or a pull of `decolua/9router:latest` drops it, and
  Clef goes silent again. Either a 9router release with #5687 merged, or a
  startup step in the `router9` compose that reapplies it (not done).
- A custom model entry `cf/@cf/cloudflare/clef` in 9router fails for another
  reason: 9router sends Cloudflare the full id `@cf/cloudflare/clef`, and
  Cloudflare accepts only `clef` or `clef-flash` (error 5006). The built-in
  Clef Flash entry maps its id; custom entries do not. Not changed.
