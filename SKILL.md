---
name: tenable-iac-finding-to-pr
description: >-
  Fetch Infrastructure-as-Code (IaC) security findings from Tenable Cloud
  Security (TCS) and open a GitHub pull request that fixes them. Use this
  whenever the user wants to remediate, fix, or open a PR for Tenable / TCS /
  Cloud Security IaC or Terraform misconfiguration findings, "code scan"
  findings, or ICodeConfigurationRisk / CodeFinding results — even if they only
  say "fix my tenable findings" or "open a PR for the cloud security findings in
  this repo". The workflow is interactive: it first verifies the TCS MCP is
  connected (and gives install steps if not), surfaces the findings, asks
  whether to open one combined PR or one PR per finding, and only then authors
  minimal Terraform fixes and opens the PR(s) — each with a findings table that
  links back to the platform.
---

# Tenable IaC Finding → PR

Turn open Tenable Cloud Security IaC findings for a repository into reviewed,
mergeable pull requests. This skill is **interactive by design**: never open a
PR before the user has seen the findings and chosen how they want them split.

The platform gives you the *intent* of a fix (the policy name + description),
not the code. You author the minimal Terraform change yourself, following the
rules in `references/fix-rules.md`, and you write the PR using the exact
template in `references/pr-template.md`.

Work through the steps in order. Do not skip Step 1 or Step 4.

## Step 1 — Verify the TCS MCP is connected

The skill is useless without the Tenable MCP. Before anything else, confirm the
`TCS` server is reachable by making one trivial call:

- Run `mcp__TCS__udm_get_object_types` (or any `mcp__TCS__*` tool).
- If the `mcp__TCS__*` tools are **not present** in this session, or the call
  fails with a connection/auth error, the MCP is not installed or not active.
  **Stop** and give the user the install steps from
  `references/mcp-setup.md` (adapt to their transport). Then wait for them to
  reconnect before continuing.

Do not fabricate findings or proceed from memory if the MCP is down.

## Step 2 — Identify the repository and fetch open findings

Findings are keyed by an **account id** of the form `github.com/<owner>/<repo>`.

1. **Determine the target.**
   - **If the user named a repo in their prompt**, use it (normalize to
     `github.com/<owner>/<repo>`).
   - **If they did not, do not assume — ask.** Ask which repo they want, or
     whether they want findings across **all repos**. If the current directory
     is a checkout, offer its git remote as a suggested default
     (`git -C <repo> remote get-url origin`), and list what TCS has to choose
     from (`references/queries.md` → "List repositories that have findings").
     Wait for their answer before querying.
2. **Fetch open findings.** Always filter `Statuses: [Open]` — never try to
   "fix" findings that are already Closed.
   - **Single repo:** run the primary query in `references/queries.md` with that
     account id.
   - **All repos:** enumerate the repos that have open code findings (with
     counts), show them to the user, and work through them **one repo at a
     time** — each repo needs its own checkout and its own PR(s). Confirm the
     scope before touching any code.

Each `CodeFinding` gives you: `Id`, `Severity`, `Status`, `Description`,
`Link` (a ready-made console URL — use it verbatim, don't build your own),
`FilePath`, and `Policy { Id Name Description Category }`.

> The MCP-queryable findings come from a **connected repo (SCM/OAuth connector)**.
> Pipeline "Code Scan" results from the GitHub Action are a separate store the
> MCP cannot query, and the MCP can under-report vs. the Code Scans UI. If the
> user insists a finding exists that the query doesn't return, say so plainly
> rather than inventing it. See `references/mcp-setup.md`.

## Step 3 — Surface the findings to the user

Show a compact table so the user knows exactly what will be fixed. One row per
finding, most severe first:

| # | Severity | Policy | Resource / File | Platform |
|---|----------|--------|-----------------|----------|
| 1 | High | Security Group unrestricted inbound internet access | `aws_security_group.risky_sg` (`main.tf`) | [view](<Link>) |

Use the finding's `Link` field for the "Platform" link. If you can already tell
a finding is one you cannot fix confidently from the code (root cause outside
the repo, ambiguous resource match), flag it here so the user isn't surprised.

## Step 4 — Ask how to split the work (required)

Ask the user explicitly, and wait for an answer:

> I found N open findings. Do you want **one PR that fixes all of them**, or
> **one PR per finding**?

Do not assume. Both are common: one combined PR is tidier for a small batch;
one-per-finding gives independent review/revert. Only after they confirm do you
touch any code.

## Step 5 — Author the fixes

For each finding you're going to fix:

1. Read the affected file (`FilePath`). Match the resource by its **exact name**
   from the finding — files often hold several resources of the same type.
2. Apply the **minimal** change that satisfies the policy, following every rule
   in `references/fix-rules.md` (minimal diff, never rename or remove resources,
   never fabricate values, preserve formatting). The policy `Name` +
   `Description` tell you the intent; `references/fix-patterns.md` has known
   Terraform patterns for common policies.
3. If you cannot determine the correct fix with confidence, **do not guess**.
   Leave that finding out of the change set and note in the PR body that it
   needs manual review (the template covers this).

Keep a per-finding record of what you changed (resource, file, what/why) — you
need it for the PR body and commit message.

## Step 6 — Open the PR(s)

Write the PR strictly per `references/pr-template.md`:
- Opening sentence **verbatim**:
  `Automated remediation for a security finding detected by Tenable Cloud Security.`
- A **findings table** with per-finding platform links (as in Step 3).
- Per-finding `### Risk` and `### Remediation Applied` sections grounded in the
  policy — no generic filler.
- Close with the auto-generated / review-before-merge note.
- `prTitle` 6–12 words; `commitMessage` a single conventional-commit line ≤70 chars.

**The PR body contains ONLY the sections the template defines — nothing more.**
Do not append environment or `terraform fmt`/`validate` notes, an "Additional
observations" section, out-of-scope findings the scan didn't return, or any
other commentary. If you have such notes (e.g. a validation you couldn't run, or
a related misconfiguration the scan missed), give them to the **user in chat** —
never in the PR.

Then create the branch, commit, push, and open the PR with
`scripts/open_fix_pr.sh` (it enforces the commit-attribution and gh-account
guards). For **one combined PR**, stage all edits on one branch. For **one PR
per finding**, run the flow once per finding on its own branch, each opened
against a clean base.

Finish by giving the user the PR URL(s).

## Gotchas (read `references/mcp-setup.md` for detail)

- **gh account flips.** `gh` can silently switch its active account during auth
  operations, making a private repo invisible (404s). The helper checks the
  active account is the expected one before pushing.
- **git credential re-sync.** After `gh auth refresh`, a "Repository not found"
  on push is usually a stale credential helper — `gh auth setup-git -h github.com`.
- **Commit messages.** No "Claude Code" attribution, no `Co-Authored-By`. The
  helper's commit template already complies.
- **MCP vs Code Scan.** MCP sees connected-repo findings only; the Code Scans UI
  may show more. Don't invent the difference away.
