---
type: plan
status: "not started"
verified: "no (owner's description and model docs 2026-10-31; nothing measured on the GPU VM)"
hosts:
  - XCP-ng host
  - Remote VPS
tags:
  - plan
  - hindsight
  - llm
  - gpu
---

# Self-hosted d1-2B in Hindsight's reranker chain

**Status:** not started.
**Goal:** LiquidAI's d1-2B runs on a homelab GPU VM, loads only when a request
arrives and unloads when idle, and serves as a member of Hindsight's reranker
chain, with its context size and batch settings chosen from measured VRAM use
rather than guessed.
**Done when:** a table of context size vs VRAM, measured on the GPU VM, is in
this plan; the VRAM is freed after the idle timeout (checked with
`nvidia-smi`); and a Hindsight recall is answered through d1 with the call
visible in 9router's request log.

## What d1-2B is

A 1.92-billion-parameter *decision* model, not a chat model. It takes a
`state` (text, a document or JSON) and named questions, and answers all of
them in one pass without generating text. Question types in llama.cpp:
`noul` (yes/no, returns P(yes)), `choice` (pick one key from `criteria`),
`score` (ordered levels, returns the median and the distribution). It is served
by `llama-server` on the `/v1/systemone` endpoint, and needs llama.cpp b11960
or newer. Source: the model card on Hugging Face (`LiquidAI/d1-2B`,
`LiquidAI/d1-2B-GGUF`) as summarised in the owner's notes, 2026-10-31.

**Where it fits:** Hindsight's reranker chain already uses models of this
kind (SystemOne decision models): Jev first, Clef as fallback, Mercury Decide
last (owner, 2026-10-31). An earlier agent session concluded d1 could not take
a reranker slot because the slot expects query-plus-documents scoring. The
owner says otherwise, so step 1 checks how 9router calls these models before
anything else is built.

## Constraints

- **On demand.** No VRAM used while idle. The model loads on the first
  request and unloads after an idle timeout. The usual tool is `llama-swap`, a
  proxy that starts `llama-server` per request and stops it after a `ttl`
  (**UNTESTED** here). Cost: the first request after an idle period waits for
  the model to load (seconds; not measured).
- **Latency vs on demand.** Per-turn latency matters more to the owner than
  token cost (Hindsight tuning notes, 2026-10-29). A cold start on every first
  recall in a while may be too slow for the first slot. Owner to decide: d1 as
  first slot (accept cold starts, or a longer idle timeout) or as a fallback
  slot (cold starts are rarely felt).
- **Distance.** Hindsight and 9router run on the VPS; the GPU VM is at home. Each
  rerank call crosses the tailnet. Measure the round trip in step 5.
- **Not open to the network.** `llama-server` has no authentication unless
  started with `--api-key`. Listen on the GPU VM's tailnet or LAN address only,
  with an API key that lives in OpenBao and that 9router sends.
- **GPU.** The owner's notes mention a GTX 1050 Ti: 4 GB VRAM, Pascal, no
  hardware bfloat16, so the unquantised BF16 weights are out; use a GGUF quant
  with every layer on the GPU (`-ngl 99`). Which GPU the VM gets is not
  recorded in `inventory/` yet.

## Quantisation: a contradiction to settle by measuring

- The owner's notes table: Q8_0 ~1.8 GB file / ~2.2 GB VRAM ("near-lossless");
  Q4_K_M ~1.1 GB / ~1.5 GB, suggested for 4 GB cards.
- An earlier session (2026-10-30) recommended Q8_0 and warned that Q4_K_M
  ships a mismatched vision projector and damages calibration.
- Step 3 measures both. Calibration matters here because the reranker uses
  the probabilities, not only the top answer.

## Measuring VRAM against context

What uses VRAM: the weights (fixed per quant), the KV cache (grows with
context size `-c`), and the compute buffers (grow with batch `-b` and
micro-batch `-ub`). The owner's draft runner used `-b 8192 -ub 8192`, which
may cost more VRAM than the card can spare; measure, don't assume.

For each quant, start `llama-server` with one setting changed at a time and
record `nvidia-smi --query-gpu=memory.used --format=csv` after loading and
after one real request (**UNTESTED**):

| Quant | `-c` | `-b` / `-ub` | KV cache type | VRAM after load | VRAM after a request | ms per request |
|---|---|---|---|---|---|---|
| Q8_0 | 4096 | 2048 / 512 | f16 | | | |
| Q8_0 | 8192 | 2048 / 512 | f16 | | | |
| Q8_0 | 16384 | 2048 / 512 | f16 | | | |
| Q8_0 | 32768 | 2048 / 512 | q8_0 | | | |
| Q4_K_M | (same rows) | | | | | |

Also try flash attention (`-fa`) and a quantised KV cache
(`--cache-type-k q8_0 --cache-type-v q8_0`), which shrink the KV cache. The
context actually needed depends on how big one rerank request is (a query plus
its candidate memories). Read a few real request sizes from 9router's log in
step 1 and size `-c` to the largest with headroom. Defaults are set from this
table, not from the model card.

## Steps

1. **Check the integration path.** In 9router, find how a SystemOne reranker
   (Jev) is called: request shape, endpoint, which fields Hindsight sends.
   Record a few request sizes in tokens. — gate: written here: whether d1 can
   take a slot as is, or needs an adapter, and the largest request size.
2. **GPU VM.** A VM on the XCP-ng host with the GPU passed through, NVIDIA
   driver, llama.cpp b11960 or newer built with CUDA. Snapshot rule for new VMs
   first (`systems/xcp-ng.md`). Add the VM to `inventory/hosts.md`. — gate:
   `nvidia-smi` shows the card inside the VM.
3. **Measure.** Fill the table above for Q8_0 and Q4_K_M, and compare their
   answers on the same 20 real rerank requests. — gate: table filled; quant and
   defaults chosen and written here with the reason.
4. **On demand.** Put `llama-swap` (or an alternative chosen in this step) in
   front with the chosen defaults and an idle `ttl`. — gate: VRAM drops to the
   driver baseline after the ttl, and the first request after that succeeds;
   cold-start time recorded here.
5. **Wire into 9router and Hindsight.** Add d1 as a 9router provider over the
   tailnet with its API key from OpenBao, then into the reranker chain in the
   slot the owner chose. Measure VPS → GPU VM round trip. — gate: one
   Hindsight recall shows the d1 call in 9router's log.
6. **Compare and decide.** A few days of normal use against the current
   chain: answer quality on recalls the owner checks, latency, misses. — gate:
   owner keeps, moves or removes the slot; the outcome goes to `journal/` and
   the running state to `inventory/services.md`.

## Draft scripts

The owner's checkout has a `nextinline/` folder (untracked) with a draft
runner (`run.sh`) and two example clients. They are kept out of this repo. Its
useful content (the endpoint contract, question types, version requirement
and quantisation notes) is summarised above. The plan assumes a clean rebuild
in steps 2–4 that uses the measured defaults; whether to keep the folder as a
reference until then is the owner's choice.

## Links

`plans/README.md`, `systems/xcp-ng.md`, `systems/openbao.md`,
`inventory/hosts.md`, `inventory/services.md`.
