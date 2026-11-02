#!/usr/bin/env python3
"""Run Prime Agent as the pull-request reviewer and act on its result.

Called by .github/workflows/prime-review.yml; documented in
repo/prime-reviewer.md. Steps:

1. Work out the mode: `review` (PR opened, or `/prime` / `/prime review ...`)
   or `instruct` (`/prime <anything else>`).
2. Check out the PR head, restore this PR's saved session from the private
   repo's `state` branch.
3. Run Prime with a scrubbed environment: it gets the model key and its
   inputs, never the GitHub token.
4. Check the commits it made (allowed paths, the properties check from main)
   and push them with the App token.
5. Post a review: suggestions and design comments on diff lines, the rest in
   the summary. In instruct mode, reply to the comment.
6. Save the session and a per-run trace to the `state` branch, and propose
   any change it made to its own playbook as a PR on the private repo.
"""

from __future__ import annotations

import base64
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

WORK = Path.cwd()
RULES = WORK / "rules"
AGENT = WORK / "agent"
PR_DIR = WORK / "pr"
STATE = WORK / "state"
TMP = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
OUT = TMP / "prime-out"
SESSION = TMP / "prime-session"
PRIME = Path.home() / ".local/bin/prime-agent"

REPO = os.environ["REPO"]
OWNER = os.environ["OWNER"]
CONFIG_REPO = f"{OWNER}/prime-reviewer"
PR = os.environ["PR_NUMBER"]
RUN_ID = os.environ["RUN_ID"]
RUN_URL = os.environ["RUN_URL"]
EVENT = os.environ["EVENT_NAME"]
TOKEN = os.environ["GH_TOKEN"]
MODEL = os.environ.get("PRIME_MODEL", "deepseek-v4.1-flash")

# Paths the reviewer may never change by itself (AGENTS.md edit table).
DENY = re.compile(
    r"^(iac/|decisions/|\.github/|\.githooks/|AGENTS\.md$|README\.md$|CLAUDE\.md$)"
)


def log(msg: str) -> None:
    print(f"prime-review: {msg}", flush=True)


def run(cmd, cwd=None, check=True, env=None, capture=True, input_=None):
    r = subprocess.run(
        cmd, cwd=cwd, env=env, text=True, input=input_,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )
    if check and r.returncode != 0:
        # Never echo the command line: it may hold an auth header.
        raise RuntimeError(f"{cmd[0]} {cmd[1] if len(cmd) > 1 else ''} failed: "
                           f"{(r.stderr or '')[-800:]}")
    return r


def gh_api(path: str, method: str = "GET", body: dict | None = None, check=True):
    cmd = ["gh", "api", "-X", method, path]
    if body is not None:
        cmd += ["--input", "-"]
    r = run(cmd, check=check, input_=json.dumps(body) if body is not None else None)
    return json.loads(r.stdout) if r.stdout.strip() else None


def auth_header() -> str:
    b = base64.b64encode(f"x-access-token:{TOKEN}".encode()).decode()
    return f"http.https://github.com/.extraheader=AUTHORIZATION: basic {b}"


def git(args, cwd, auth=False, check=True):
    cmd = ["git"] + (["-c", auth_header()] if auth else []) + args
    return run(cmd, cwd=cwd, check=check)


def react(content: str) -> None:
    cid = os.environ.get("COMMENT_ID")
    if not cid:
        return
    kind = "pulls/comments" if EVENT == "pull_request_review_comment" else "issues/comments"
    gh_api(f"repos/{REPO}/{kind}/{cid}/reactions", "POST", {"content": content}, check=False)


# ---------------------------------------------------------------- mode -----

def parse_mode() -> tuple[str, str, str]:
    """Return (mode, instruction, focus)."""
    if EVENT == "pull_request":
        focus = "\n".join(
            l[len("/prime"):].strip() for l in os.environ.get("PR_BODY", "").splitlines()
            if l.startswith("/prime")
        )
        return "review", "", focus
    body = os.environ.get("COMMENT_BODY", "")
    text = body[len("/prime"):].strip()
    m = re.match(r"(?is)^review\b(.*)$", text)
    if not text or m:
        return "review", "", (m.group(1).strip() if m else "")
    if EVENT == "pull_request_review_comment":
        ctx = f"(On {os.environ.get('COMMENT_PATH')} line {os.environ.get('COMMENT_LINE')}"
        reply_to = os.environ.get("COMMENT_REPLY_TO")
        if reply_to:
            parent = gh_api(f"repos/{REPO}/pulls/comments/{reply_to}", check=False) or {}
            ctx += f", replying to this comment:\n{parent.get('body', '')[:3000]}\n"
        text = ctx + ")\n\n" + text
    return "instruct", text, ""


# ------------------------------------------------------------- checkout ----

def checkout_pr() -> dict:
    pr = gh_api(f"repos/{REPO}/pulls/{PR}")
    if pr["head"]["repo"]["full_name"] != REPO:
        raise SystemExit("pull request from a fork: not reviewed")
    if pr["state"] != "open":
        log("pull request is not open: fixes will not be pushed")
    if PR_DIR.exists():
        shutil.rmtree(PR_DIR)
    run(["git", "-c", auth_header(), "clone", "--quiet", "--no-tags",
         "--branch", pr["head"]["ref"], f"https://github.com/{REPO}.git", str(PR_DIR)])
    git(["fetch", "--quiet", "origin", pr["base"]["ref"]], PR_DIR)
    base = git(["merge-base", "HEAD", f"origin/{pr['base']['ref']}"], PR_DIR).stdout.strip()
    head = git(["rev-parse", "HEAD"], PR_DIR).stdout.strip()
    bot = gh_api(f"users/{os.environ['APP_SLUG']}%5Bbot%5D")
    git(["config", "user.name", f"{os.environ['APP_SLUG']}[bot]"], PR_DIR)
    git(["config", "user.email",
         f"{bot['id']}+{os.environ['APP_SLUG']}[bot]@users.noreply.github.com"], PR_DIR)
    return {"pr": pr, "base": base, "head": head}


def checkout_state() -> None:
    url = f"https://github.com/{CONFIG_REPO}.git"
    r = run(["git", "-c", auth_header(), "clone", "--quiet", "--depth", "1",
             "--branch", "state", url, str(STATE)], check=False)
    if r.returncode != 0:
        log("no state branch yet: starting one")
        STATE.mkdir(parents=True, exist_ok=True)
        git(["init", "--quiet", "-b", "state"], STATE)
        git(["remote", "add", "origin", url], STATE)
        (STATE / "README.md").write_text(STATE_README)
    for d in (STATE, AGENT):
        git(["config", "user.name", f"{os.environ['APP_SLUG']}[bot]"], d)
        git(["config", "user.email", f"{os.environ['APP_SLUG']}[bot]@users.noreply.github.com"], d)


STATE_README = """# Reviewer state

Written only by the `prime review` workflow in the homelab repo.

- `sessions/pr-<n>/`: Prime Agent's session folder for that pull request.
  Restored before every run on the PR, so `/prime <instruction>` continues
  the same conversation.
- `traces/<run-id>/`: one folder per run, kept forever:
  - `meta.json`: run id, PR, mode, model, Prime version, start time,
    duration, head commit before and after, verdict, counts, token usage
    and cost summed over this run's model turns.
  - `result.json`: the reviewer's structured result.
  - `session.jsonl`: the session file as it was after this run (every
    message, tool call and usage record). The run's own records are the
    lines after `meta.json`'s `session_lines_before`.

`meta.json` and `session.jsonl` are the input for a future trace importer
(OpenTelemetry to Phoenix, Langfuse or OpenObserve).
"""


# ------------------------------------------------------------------ run ----

def run_prime(ctx: dict, mode: str, instruction: str, focus: str) -> dict:
    if SESSION.exists():
        shutil.rmtree(SESSION)
    saved = STATE / "sessions" / f"pr-{PR}"
    resume = saved.exists() and any(saved.glob("*.jsonl"))
    if resume:
        shutil.copytree(saved, SESSION)
    else:
        SESSION.mkdir(parents=True)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "result.json").unlink(missing_ok=True)

    session_file = next(iter(sorted(SESSION.glob("*.jsonl"))), None)
    lines_before = sum(1 for _ in open(session_file)) if session_file else 0

    env = {
        "PATH": f"{Path.home()}/.local/bin:/usr/local/bin:/usr/bin:/bin",
        "HOME": str(Path.home()),
        "USER": os.environ.get("USER", "runner"),
        "LANG": "C.UTF-8",
        "TERM": "dumb",
        "TMPDIR": str(TMP),
        "DO_NOT_TRACK": "1",
        "OPENCODE_API_KEY": os.environ["OPENCODE_API_KEY"],
        "PRIME_AGENT_CODING_AGENT_DIR": str(AGENT),
        "BASE": ctx["base"],
        "HEAD": ctx["head"],
        "RULES_DIR": str(RULES),
        "PRIME_OUT": str(OUT),
        "PRIME_MODE": mode,
        "PRIME_INSTRUCTION": instruction,
        "PRIME_FOCUS": focus,
    }
    if mode == "review":
        prompt = (f"Review pull request #{PR} (diff $BASE..$HEAD). Follow your core and "
                  "the homelab-review skill, fix level 1 findings as commits, and write "
                  "$PRIME_OUT/result.json.")
        if focus:
            prompt += " The owner asked for this focus: see $PRIME_FOCUS."
    else:
        prompt = (f"The owner left an instruction on pull request #{PR}: read it from "
                  "$PRIME_INSTRUCTION. Do it under your core's rules (the PR's state may "
                  "have changed since your last run: re-read what you need), and write "
                  "$PRIME_OUT/result.json with the reply filled in.")
    cmd = [str(PRIME), "-p", "--session-dir", str(SESSION), "--provider", "opencode-go",
           "--model", MODEL, "--thinking", "high"]
    if resume:
        cmd.append("-c")
    cmd.append(prompt)

    started = time.time()
    log(f"running Prime ({mode}, resume={resume})")
    r = subprocess.run(cmd, cwd=PR_DIR, env=env, text=True, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=2400)
    subprocess.run([str(PRIME), "shutdown"], env=env, capture_output=True)
    duration = round(time.time() - started)
    log(f"Prime exited {r.returncode} after {duration}s")
    # Only the last line of Prime's output reaches the public log.
    tail = (r.stdout or "").strip().splitlines()[-1:] or ["(no output)"]
    log(f"Prime said: {tail[0][:300]}")

    result = None
    try:
        result = json.loads((OUT / "result.json").read_text())
    except (OSError, ValueError) as e:
        log(f"no usable result.json ({e.__class__.__name__})")
    return {"result": result, "exit": r.returncode, "duration": duration,
            "started": started, "lines_before": lines_before,
            "stdout": r.stdout or ""}


# -------------------------------------------------------------- commits ----

def check_and_push(ctx: dict) -> tuple[str, list[str], str]:
    """Return (new head, list of pushed commit lines, note)."""
    new_head = git(["rev-parse", "HEAD"], PR_DIR).stdout.strip()
    if new_head == ctx["head"]:
        return ctx["head"], [], ""
    if git(["merge-base", "--is-ancestor", ctx["head"], new_head], PR_DIR,
           check=False).returncode != 0:
        git(["reset", "--hard", ctx["head"]], PR_DIR)
        return ctx["head"], [], "the reviewer rewrote history; its commits were dropped"
    if git(["status", "--porcelain"], PR_DIR).stdout.strip():
        git(["stash", "--include-untracked"], PR_DIR, check=False)
    changed = git(["diff", "--name-only", f"{ctx['head']}..{new_head}"], PR_DIR).stdout.split()
    bad = [p for p in changed if DENY.match(p)]
    if bad:
        git(["reset", "--hard", ctx["head"]], PR_DIR)
        return ctx["head"], [], f"its commits touched protected paths ({', '.join(bad)}); not pushed"
    chk = run(["python3", "-I", str(RULES / ".githooks/check-properties.py")],
              cwd=PR_DIR, check=False)
    if chk.returncode != 0:
        git(["reset", "--hard", ctx["head"]], PR_DIR)
        return ctx["head"], [], "the properties check failed after its commits; not pushed"
    if ctx["pr"]["state"] != "open":
        git(["reset", "--hard", ctx["head"]], PR_DIR)
        return ctx["head"], [], "the pull request is closed; commits not pushed"
    git(["push", "--quiet", "origin", f"HEAD:refs/heads/{ctx['pr']['head']['ref']}"],
        PR_DIR, auth=True)
    commits = git(["log", "--format=%h %s", f"{ctx['head']}..{new_head}"], PR_DIR).stdout.splitlines()
    return new_head, commits, ""


# --------------------------------------------------------------- review ----

def diff_lines(base: str, head: str) -> dict[str, set[int]]:
    """Right-side line numbers GitHub accepts comments on, per file."""
    out: dict[str, set[int]] = {}
    diff = git(["diff", "--unified=3", "--no-color", f"{base}..{head}"], PR_DIR).stdout
    path, n = None, 0
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
            continue
        m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if m:
            n = int(m.group(1))
            continue
        if path is None or line.startswith(("---", "diff ", "index ")):
            continue
        if line.startswith("+") or line.startswith(" "):
            out.setdefault(path, set()).add(n)
            n += 1
    return out


def finding_body(f: dict) -> str:
    tag = "blocker" if f.get("blocker") else "warning"
    b = f"**L{f.get('level')} · section {f.get('section')} · {tag}: {f.get('title', '').strip()}**\n\n"
    b += f.get("body", "").strip()
    if f.get("level") == 2 and f.get("suggestion") is not None:
        b += "\n\n```suggestion\n" + f["suggestion"].rstrip("\n") + "\n```"
    return b


def post_review(ctx: dict, new_head: str, res: dict, commits: list[str], note: str,
                meta: dict, learn_url: str) -> None:
    result = res["result"]
    footer = (f"\n\n<sub>prime-reviewer · run `{RUN_ID}` · {meta['duration_s']}s · "
              f"{meta['usage']['output']} output tokens · [log]({RUN_URL})</sub>")
    if result is None:
        body = ("Prime finished without a result file. Last lines of its answer:\n\n"
                + "\n".join("> " + l for l in res["stdout"].strip().splitlines()[-15:]))
        gh_api(f"repos/{REPO}/issues/{PR}/comments", "POST", {"body": body + footer})
        return

    parts = []
    if res.get("mode") == "instruct":
        parts.append(result.get("reply", "").strip() or "(no reply)")
    else:
        parts.append(f"**Verdict: {result.get('verdict', '?')}**\n\n{result.get('summary', '').strip()}")
    if commits:
        parts.append("**Pushed fixes**\n" + "\n".join(f"- {c}" for c in commits))
    if note:
        parts.append(f"**Not pushed:** {note}")

    lines = diff_lines(ctx["base"], new_head)
    inline, rest = [], []
    for f in result.get("findings", []) or []:
        path, line = f.get("path"), f.get("line")
        start = f.get("start_line") or line
        ok = (isinstance(line, int) and isinstance(start, int) and start <= line
              and path in lines and all(n in lines[path] for n in range(start, line + 1)))
        if ok:
            c = {"path": path, "line": line, "side": "RIGHT", "body": finding_body(f)}
            if start != line:
                c.update(start_line=start, start_side="RIGHT")
            inline.append(c)
        else:
            rest.append(f)
    if rest:
        parts.append("**Outside the diff**\n\n" + "\n\n".join(
            f"`{f.get('path')}:{f.get('line')}` — " + finding_body(f) for f in rest))
    if learn_url:
        parts.append(f"I proposed a change to my playbook: {learn_url}")
    body = "\n\n".join(parts) + footer

    if res.get("mode") == "instruct" and not inline:
        if EVENT == "pull_request_review_comment":
            r = gh_api(f"repos/{REPO}/pulls/{PR}/comments/{os.environ['COMMENT_ID']}/replies",
                       "POST", {"body": body}, check=False)
            if r:
                return
        gh_api(f"repos/{REPO}/issues/{PR}/comments", "POST", {"body": body})
        return
    review = {"commit_id": new_head, "event": "COMMENT", "body": body, "comments": inline}
    r = run(["gh", "api", "-X", "POST", f"repos/{REPO}/pulls/{PR}/reviews", "--input", "-"],
            check=False, input_=json.dumps(review))
    if r.returncode != 0:
        log("inline review rejected; posting everything as one comment")
        allf = "\n\n".join(f"`{c['path']}:{c['line']}` — {c['body']}" for c in inline)
        gh_api(f"repos/{REPO}/issues/{PR}/comments", "POST",
               {"body": body.replace(footer, "") + ("\n\n" + allf if allf else "") + footer})


# ---------------------------------------------------------------- state ----

def usage_since(lines_before: int) -> dict:
    u = {"turns": 0, "tool_calls": 0, "input": 0, "output": 0, "cache_read": 0, "cost": 0.0}
    f = next(iter(sorted(SESSION.glob("*.jsonl"))), None)
    if not f:
        return u
    for i, line in enumerate(open(f)):
        if i < lines_before:
            continue
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("type") == "tool_started":
            u["tool_calls"] += 1
        m = e.get("message") or {}
        if m.get("role") == "assistant":
            u["turns"] += 1
            x = m.get("usage") or {}
            u["input"] += x.get("input", 0) or 0
            u["output"] += x.get("output", 0) or 0
            u["cache_read"] += x.get("cacheRead", 0) or 0
            c = x.get("cost")
            u["cost"] += c.get("total", 0) if isinstance(c, dict) else 0
    u["cost"] = round(u["cost"], 5)
    return u


def save_state(meta: dict, res: dict) -> None:
    saved = STATE / "sessions" / f"pr-{PR}"
    if saved.exists():
        shutil.rmtree(saved)
    shutil.copytree(SESSION, saved)
    trace = STATE / "traces" / RUN_ID
    trace.mkdir(parents=True, exist_ok=True)
    (trace / "meta.json").write_text(json.dumps(meta, indent=2) + "\n")
    if res["result"] is not None:
        (trace / "result.json").write_text(json.dumps(res["result"], indent=2) + "\n")
    f = next(iter(sorted(SESSION.glob("*.jsonl"))), None)
    if f:
        shutil.copy(f, trace / "session.jsonl")
    git(["add", "-A"], STATE)
    git(["commit", "--quiet", "-m", f"Run {RUN_ID} on PR {PR} ({meta['mode']})"], STATE)
    for attempt in range(4):
        if git(["push", "--quiet", "origin", "HEAD:refs/heads/state"], STATE, auth=True,
               check=False).returncode == 0:
            return
        git(["pull", "--quiet", "--rebase", "origin", "state"], STATE, auth=True, check=False)
        time.sleep(2 + attempt * 3)
    log("could not save state after retries")


def propose_learning() -> str:
    if not git(["status", "--porcelain"], AGENT).stdout.strip():
        return ""
    branch = f"learn/pr-{PR}-{RUN_ID}"
    git(["checkout", "--quiet", "-b", branch], AGENT)
    git(["add", "-A"], AGENT)
    git(["commit", "--quiet", "-m", f"Lesson from homelab PR {PR} (run {RUN_ID})"], AGENT)
    git(["push", "--quiet", "origin", f"HEAD:refs/heads/{branch}"], AGENT, auth=True)
    diff = git(["show", "--stat", "--patch", "HEAD"], AGENT).stdout[:60000]
    pr = gh_api(f"repos/{CONFIG_REPO}/pulls", "POST", {
        "title": f"Lesson from homelab PR {PR}",
        "head": branch, "base": "main",
        "body": (f"The reviewer changed its own playbook during run `{RUN_ID}` on "
                 f"{REPO}#{PR}. Merge to keep it, close to drop it.\n\n```diff\n{diff}\n```"),
    }, check=False)
    return (pr or {}).get("html_url", "")


# ----------------------------------------------------------------- main ----

def main() -> None:
    mode, instruction, focus = parse_mode()
    react("eyes")
    ctx = checkout_pr()
    checkout_state()
    git(["remote", "set-url", "origin", f"https://github.com/{CONFIG_REPO}.git"], AGENT)
    res = run_prime(ctx, mode, instruction, focus)
    res["mode"] = mode
    new_head, commits, note = check_and_push(ctx)
    result = res["result"] or {}
    meta = {
        "run_id": RUN_ID, "run_url": RUN_URL, "repo": REPO, "pr": int(PR), "mode": mode,
        "event": EVENT, "model": MODEL, "prime_version": os.environ.get("PRIME_AGENT_VERSION"),
        "started": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(res["started"])),
        "duration_s": res["duration"], "prime_exit": res["exit"],
        "head_before": ctx["head"], "head_after": new_head, "base": ctx["base"],
        "verdict": result.get("verdict"),
        "findings": len(result.get("findings") or []), "fixes_pushed": len(commits),
        "push_note": note, "session_lines_before": res["lines_before"],
        "usage": usage_since(res["lines_before"]),
    }
    learn_url = propose_learning()
    meta["playbook_pr"] = learn_url
    post_review(ctx, new_head, res, commits, note, meta, learn_url)
    save_state(meta, res)
    react("rocket" if res["result"] is not None else "confused")
    log(f"done: {json.dumps({k: meta[k] for k in ('verdict', 'findings', 'fixes_pushed', 'duration_s')})}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # report, never dump the environment
        log(f"failed: {e.__class__.__name__}: {str(e)[:500]}")
        react("confused")
        sys.exit(1)
