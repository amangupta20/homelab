"""Import finished Prime reviewer runs from B2 into Langfuse as OpenTelemetry spans.

The boundary is prime-reviewer-action's observability.md: read completed run archives (here with the reviewer's own key, README),
convert the Prime JSONL records into spans, send them to Langfuse's OTLP endpoint, and remember what was imported.
Standard library only. README: apps/vps/langfuse/README.md, "Importer".

    python3 import_runs.py loop            check B2 every IMPORT_INTERVAL seconds (the container's command)
    python3 import_runs.py once            one pass, then exit
    python3 import_runs.py convert FILE    print the conversion summary for one local .tar.gz archive (no network)
    python3 import_runs.py verify KEY      compare a run's imported usage with its metadata
"""

import base64
import datetime
import gzip
import hashlib
import io
import json
import os
import sys
import tarfile
import time
import urllib.parse
import urllib.request

ADAPTER = "prime-langfuse/2"  # 2: the root span carries the run's input and output (README, "Importer")
STATE_FILE = os.environ.get("IMPORT_STATE", "/state/imported.json")
MAX_TEXT = 100_000  # characters kept per input or output; a longer value is cut and says so


def log(*parts):
    print(datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ"), *parts, flush=True)


# ---------- conversion (no network) ----------

def _hex(*parts, n):
    return hashlib.sha256("|".join(parts).encode()).hexdigest()[:n]


def _ns(ts):
    """ISO timestamp, or milliseconds since the epoch, to nanoseconds as a string."""
    if isinstance(ts, (int, float)):
        return str(int(ts * 1_000_000))
    return str(int(datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp() * 1_000_000_000))


def _cut(value):
    text = value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)
    if len(text) > MAX_TEXT:
        text = text[:MAX_TEXT] + f"\n[cut by the importer: {len(text)} characters in the archive]"
    return text


def _attr(key, value):
    if isinstance(value, bool):
        return {"key": key, "value": {"boolValue": value}}
    if isinstance(value, int):
        return {"key": key, "value": {"intValue": str(value)}}
    if isinstance(value, float):
        return {"key": key, "value": {"doubleValue": value}}
    if isinstance(value, list):
        return {"key": key, "value": {"arrayValue": {"values": [{"stringValue": str(v)} for v in value]}}}
    return {"key": key, "value": {"stringValue": value if isinstance(value, str) else json.dumps(value)}}


def _span(trace_id, span_id, parent, name, start, end, attrs, error=False):
    span = {
        "traceId": trace_id, "spanId": span_id, "name": name, "kind": 1,
        "startTimeUnixNano": start, "endTimeUnixNano": max(end, start, key=int),
        "attributes": [_attr(k, v) for k, v in attrs.items() if v is not None],
    }
    if parent:
        span["parentSpanId"] = parent
    if error:
        span["status"] = {"code": 2}
    return span


def _text(content):
    out = []
    for part in content if isinstance(content, list) else [content]:
        if isinstance(part, dict):
            out.append(part.get("text") or part.get("thinking") or "")
        else:
            out.append(str(part))
    return "\n".join(p for p in out if p)


def _records_to_spans(records, trace_id, parent_id, salt):
    """Spans for one Prime transcript: a generation per model reply, a tool span per tool call."""
    spans, tool_start, results = [], {}, {}
    for r in records:
        if r.get("type") == "tool_started":
            tool_start[r["toolCallId"]] = r["timestamp"]
        elif r.get("type") == "message" and r["message"].get("role") == "toolResult":
            results[r["message"]["toolCallId"]] = r
    prev_ts, pending_input = None, []
    for r in records:
        if r.get("type") != "message":
            prev_ts = r.get("timestamp", prev_ts)
            continue
        m = r["message"]
        if m.get("role") in ("user", "toolResult"):
            pending_input.append({"role": m["role"], "tool": m.get("toolName"), "content": _text(m.get("content"))})
            prev_ts = r["timestamp"]
            continue
        if m.get("role") != "assistant":
            continue
        usage = m.get("usage") or {}
        cost = usage.get("cost") or {}
        end = _ns(r["timestamp"])
        start = _ns(prev_ts) if prev_ts else end
        calls = [p for p in m.get("content", []) if p.get("type") == "toolCall"]
        output = {"thinking": _text([p for p in m.get("content", []) if p.get("type") == "thinking"]),
                  "text": _text([p for p in m.get("content", []) if p.get("type") == "text"]),
                  "tool_calls": [{"name": c.get("name"), "arguments": c.get("arguments")} for c in calls]}
        gen_id = _hex(salt, r["id"], n=16)
        spans.append(_span(trace_id, gen_id, parent_id, m.get("model") or "model call", start, end, {
            "langfuse.observation.type": "generation",
            "langfuse.observation.model.name": m.get("model"),
            "gen_ai.request.model": m.get("model"),
            "langfuse.observation.input": _cut(pending_input) if pending_input else None,
            "langfuse.observation.output": _cut(output),
            "langfuse.observation.usage_details": json.dumps({
                "input": usage.get("input", 0), "output": usage.get("output", 0),
                "cache_read_input_tokens": usage.get("cacheRead", 0),
                "cache_creation_input_tokens": usage.get("cacheWrite", 0)}),
            "langfuse.observation.cost_details": json.dumps({
                "input": cost.get("input", 0), "output": cost.get("output", 0),
                "cache_read_input_tokens": cost.get("cacheRead", 0),
                "cache_creation_input_tokens": cost.get("cacheWrite", 0), "total": cost.get("total", 0)}),
            "langfuse.observation.metadata": json.dumps({"provider": m.get("provider"), "api": m.get("api"),
                                                         "stop_reason": m.get("stopReason"),
                                                         "response_id": m.get("responseId")}),
        }))
        pending_input = []
        prev_ts = r["timestamp"]
        for c in calls:
            res = results.get(c.get("id"))
            t0 = _ns(tool_start.get(c.get("id"), r["timestamp"]))
            t1 = _ns(res["timestamp"]) if res else t0
            spans.append(_span(trace_id, _hex(salt, "tool", c.get("id", ""), n=16), parent_id,
                               c.get("name") or "tool", t0, t1, {
                "langfuse.observation.type": "tool",
                "langfuse.observation.input": _cut(c.get("arguments")),
                "langfuse.observation.output": _cut(_text(res["message"].get("content"))) if res else None,
                "langfuse.observation.level": "ERROR" if res and res["message"].get("isError") else None,
                "langfuse.observation.status_message": None if res else "no result recorded for this call",
            }, error=bool(res and res["message"].get("isError"))))
    return spans


def _jsonl(data):
    return [json.loads(line) for line in data.decode().splitlines() if line.strip()]


def convert(archive_bytes, key):
    """OTLP JSON body and a summary for one trace bundle (traces/<owner>/<repo>/<pr>/<run>.tar.gz)."""
    files = {}
    with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as tar:
        for member in tar.getmembers():
            if member.isfile() and not member.name.startswith(("/", "..")):
                files[member.name] = tar.extractfile(member).read()
    meta = json.loads(files["meta.json"])
    result = json.loads(files["result.json"]) if "result.json" in files else None
    ident = meta.get("trace_id") or key
    trace_id, root_id = _hex("prime-review", ident, n=32), _hex("prime-review", ident, "root", n=16)
    before = meta.get("session_lines_before") or 0
    root_records = _jsonl(files.get("session.jsonl", b""))[before:]
    started = meta.get("started") or (root_records[0]["timestamp"] if root_records else None)
    start = _ns(started)
    end = str(int(start) + int((meta.get("duration_s") or 0) * 1_000_000_000))
    failed = bool(meta.get("error")) or meta.get("prime_exit") not in (0, None)
    first_user = next((_text(r["message"].get("content")) for r in root_records
                       if r.get("type") == "message" and r["message"].get("role") == "user"), None)
    meta_out = {k: v for k, v in meta.items() if k != "usage"}
    meta_out.update({f"usage_{k}": v for k, v in (meta.get("usage") or {}).items()})
    meta_out["importer"] = ADAPTER
    tags = [t for t in ("prime-review", meta.get("mode"), meta.get("verdict"), "failed" if failed else None) if t]
    spans = [_span(trace_id, root_id, None, f"review {meta.get('repo')}#{meta.get('pr')}", start, end, {
        "langfuse.trace.name": "prime-review",
        "langfuse.session.id": f"{meta.get('repo')}#{meta.get('pr')}",
        "langfuse.trace.tags": tags,
        "langfuse.release": meta.get("prime_version"),
        "langfuse.trace.input": _cut(first_user) if first_user else None,
        "langfuse.trace.output": _cut(result) if result is not None else None,
        # Langfuse 4 (events_only) stores no trace input or output of its own; the API returns null for the root
        # observation unless these are set too (checked 2026-11-11).
        "langfuse.observation.input": _cut(first_user) if first_user else None,
        "langfuse.observation.output": _cut(result) if result is not None else None,
        "langfuse.trace.metadata": json.dumps(meta_out),
        "langfuse.observation.type": "agent",
        "langfuse.observation.level": "ERROR" if failed else None,
        "langfuse.observation.status_message": meta.get("error") or None,
    }, error=failed)]
    spans += _records_to_spans(root_records, trace_id, root_id, ident)
    # Subagent transcripts: their own agent span each. Records from before this run started are skipped, because
    # a saved child transcript may carry earlier runs (observability.md). Their parent call is not recorded, so they
    # hang off the run's root span.
    for name in sorted(n for n in files if n.startswith("subagents/") and n.endswith(".jsonl")):
        recs = [r for r in _jsonl(files[name]) if not started or _ns(r.get("timestamp", started)) >= start]
        if not recs:
            continue
        sub_id = _hex("prime-review", ident, name, n=16)
        stamps = [_ns(r["timestamp"]) for r in recs if r.get("timestamp")]
        spans.append(_span(trace_id, sub_id, root_id, name.removeprefix("subagents/"), min(stamps, key=int),
                           max(stamps, key=int), {"langfuse.observation.type": "agent",
                                                  "langfuse.observation.metadata": json.dumps(
                                                      {"parent_call": "not recorded by Prime"})}))
        spans += _records_to_spans(recs, trace_id, sub_id, ident + "|" + name)
    body = {"resourceSpans": [{"resource": {"attributes": [_attr("service.name", "prime-reviewer")]},
                               "scopeSpans": [{"scope": {"name": ADAPTER}, "spans": spans}]}]}
    gens = [s for s in spans if any(a["key"] == "langfuse.observation.type" and
                                    a["value"].get("stringValue") == "generation" for a in s["attributes"])]
    return body, {"trace_id": trace_id, "ident": ident, "spans": len(spans), "generations": len(gens),
                  "failed": failed, "usage": meta.get("usage")}


# ---------- B2 (native API; the importer only lists and downloads) ----------

class B2:
    def __init__(self, key_id, key):
        req = urllib.request.Request("https://api.backblazeb2.com/b2api/v3/b2_authorize_account", headers={
            "Authorization": "Basic " + base64.b64encode(f"{key_id}:{key}".encode()).decode()})
        a = json.load(urllib.request.urlopen(req, timeout=60))
        s = a["apiInfo"]["storageApi"]
        self.api, self.dl, self.tok = s["apiUrl"], s["downloadUrl"], a["authorizationToken"]
        self.bucket_id, self.bucket = s.get("bucketId"), s.get("bucketName") or os.environ["B2_BUCKET"]
        if not self.bucket_id:
            r = self._post("b2_list_buckets", {"accountId": a["accountId"], "bucketName": self.bucket})
            self.bucket_id = r["buckets"][0]["bucketId"]

    def _post(self, op, body):
        req = urllib.request.Request(f"{self.api}/b2api/v3/{op}", data=json.dumps(body).encode(),
                                     headers={"Authorization": self.tok})
        return json.load(urllib.request.urlopen(req, timeout=60))

    def list(self, prefix):
        names, start = [], None
        while True:
            r = self._post("b2_list_file_names", {"bucketId": self.bucket_id, "prefix": prefix,
                                                  "maxFileCount": 1000, "startFileName": start})
            names += [f["fileName"] for f in r["files"] if f["fileName"].endswith(".tar.gz")]
            start = r.get("nextFileName")
            if not start:
                return names

    def get(self, name):
        url = f"{self.dl}/file/{self.bucket}/{urllib.parse.quote(name)}"
        return urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": self.tok}),
                                      timeout=120).read()


# ---------- Langfuse ----------

class Langfuse:
    def __init__(self, host, public_key, secret_key):
        self.host = host.rstrip("/")
        self.auth = "Basic " + base64.b64encode(f"{public_key}:{secret_key}".encode()).decode()

    def _req(self, method, path, body=None, headers=None):
        req = urllib.request.Request(self.host + path, method=method, data=body,
                                     headers={"Authorization": self.auth, **(headers or {})})
        with urllib.request.urlopen(req, timeout=180) as r:
            data = r.read()
            return json.loads(data) if data else {}

    def wake(self):
        """A GET first: while Langfuse sleeps, Sablier answers 302 once it is up, and a POST would not survive that."""
        t = time.time()
        self._req("GET", "/api/public/health")
        return time.time() - t

    def send(self, body):
        return self._req("POST", "/api/public/otel/v1/traces", gzip.compress(json.dumps(body).encode()),
                         {"Content-Type": "application/json", "Content-Encoding": "gzip"})

    def observations(self, trace_id):
        out, cursor = [], None
        while True:
            q = {"traceId": trace_id, "limit": 1000, "fields": "core,basic,usage,model",
                 **({"cursor": cursor} if cursor else {})}
            r = self._req("GET", "/api/public/v2/observations?" + urllib.parse.urlencode(q))
            out += r.get("data", [])
            cursor = (r.get("meta") or {}).get("cursor")
            if not cursor:
                return out


# ---------- the loop ----------

def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_state(state):
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1, sort_keys=True)
    os.replace(tmp, STATE_FILE)


def clients():
    e = os.environ
    return (B2(e["B2_KEY_ID"], e["B2_APPLICATION_KEY"]),
            Langfuse(e["LANGFUSE_HOST"], e["LANGFUSE_PUBLIC_KEY"], e["LANGFUSE_SECRET_KEY"]))


def one_pass():
    b2, lf = clients()
    state = load_state()
    # Langfuse 4 appends what it is sent: the same run sent twice shows every span twice (tried 2026-11-10).
    # So a key is never sent again once it is in the state, whatever adapter version imported it, and before
    # sending, Langfuse is asked whether the trace exists already (state lost, or a crash after the send).
    todo = [k for k in b2.list(os.environ.get("IMPORT_PREFIX", "traces/")) if k not in state]
    if not todo:
        return 0
    log(f"{len(todo)} run(s) to import; woke Langfuse in {lf.wake():.1f}s")
    done = 0
    for key in sorted(todo):
        try:
            body, info = convert(b2.get(key), key)
            if lf.observations(info["trace_id"]):
                state[key] = "found-in-langfuse"
                save_state(state)
                log("already in Langfuse, not sent again:", key)
                continue
            lf.send(body)
        except Exception as exc:  # one bad archive must not stop the rest; it is retried next pass
            log("FAILED", key, type(exc).__name__, str(exc)[:300])
            continue
        state[key] = ADAPTER
        save_state(state)
        done += 1
        log("imported", key, f"spans={info['spans']}", f"generations={info['generations']}",
            "failed-run" if info["failed"] else "")
    return done


def verify(key):
    b2, lf = clients()
    body, info = convert(b2.get(key), key)
    obs = lf.observations(info["trace_id"])
    gens = [o for o in obs if o.get("type") == "GENERATION"]
    got_in = sum((o.get("usageDetails") or {}).get("input", 0) for o in gens)
    got_out = sum((o.get("usageDetails") or {}).get("output", 0) for o in gens)
    got_cost = sum((o.get("costDetails") or {}).get("total", 0) for o in gens)
    u = info["usage"] or {}
    print(json.dumps({"key": key, "observations": len(obs), "spans_sent": info["spans"],
                      "generations": [len(gens), info["generations"]], "turns_in_meta": u.get("turns"),
                      "input": [got_in, u.get("input")], "output": [got_out, u.get("output")],
                      "cost": [round(got_cost, 6), u.get("cost")]}, indent=1))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "loop"
    if cmd == "convert":
        with open(sys.argv[2], "rb") as f:
            print(json.dumps(convert(f.read(), sys.argv[2])[1]))
    elif cmd == "verify":
        verify(sys.argv[2])
    elif cmd == "once":
        log(f"imported {one_pass()} run(s)")
    elif cmd == "loop":
        interval = int(os.environ.get("IMPORT_INTERVAL", "900"))
        log(f"{ADAPTER}: checking every {interval}s")
        while True:
            try:
                one_pass()
            except Exception as exc:
                log("pass failed:", type(exc).__name__, str(exc)[:300])
            time.sleep(interval)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
