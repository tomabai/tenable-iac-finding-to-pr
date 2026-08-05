# TCS MCP: install, activate, and onboarding notes

## Verifying the MCP is active

Inside a Claude Code session, the MCP is active if `mcp__TCS__*` tools are
available and a trivial call succeeds:

- `mcp__TCS__udm_get_object_types` — returns object types when connected.
- From a shell you can also list configured servers: `claude mcp list`
  (look for a `TCS` / `tenable` entry marked connected).

If the tools are absent or the call returns a connection/auth error, install it.

## Installing the TCS MCP (HTTP transport)

The Tenable Cloud Security MCP is a remote HTTP server. Add it with your own
Tenable API token — **never** paste someone else's key into a skill or repo.

```bash
claude mcp add --transport http TCS https://app.tenable.com/api/mcp \
  --header "Authorization: Bearer <YOUR_TENABLE_API_TOKEN>"
```

Some tenants use the `cloud.tenable.com` host with the classic API-key header
instead:

```bash
claude mcp add --transport http TCS https://cloud.tenable.com/mcp \
  --header "X-ApiKeys: accessKey=<ACCESS_KEY>;secretKey=<SECRET_KEY>"
```

Get the token/keys from the Tenable console (**Settings → My Account → API
Keys**, or an org API token). After adding, restart the session (or reconnect
MCP) and re-run the Step 1 check.

## Why findings might not show up

Two different onboarding paths exist, and they populate **different stores**:

1. **SCM / OAuth connector (recommended).** Connect the GitHub org/repo to TCS
   via the OAuth app. This populates the MCP-queryable finding stores
   (`ICodeConfigurationRisk` / `CodeFinding`), which is what this skill reads.
   - The connector requires the GitHub account to be an **organization**, not a
     personal account. If findings never appear, confirm the repo lives under a
     connected **org** and that the first scan has completed (it can lag after
     you connect the app).

2. **GitHub Action** (`tenable/cloud-security-actions/iac/scan@v1`). Produces a
   "Code Scan" visible in the UI under **Risks → Code Scans**, but these results
   are **not queryable via the MCP**. The Code Scans UI can also show *more*
   findings than the connected-repo scan surfaces to the MCP.

So: if the user sees findings in the Code Scans UI but the GraphQL query returns
nothing (or fewer), the repo is likely only pipeline-scanned, not
connector-onboarded. Explain that rather than fabricating results.

## gh / git gotchas that block the PR step

- **Active gh account flips.** Auth operations can silently switch `gh`'s active
  account (e.g. to `tabai_tenb`), after which a private repo 404s. Verify and
  fix: `gh auth status`, then `gh auth switch -u <expected-user>`.
- **Stale git credential helper.** After `gh auth refresh`, `git push` may fail
  with "Repository not found". Re-sync: `gh auth setup-git -h github.com`.
- **workflow scope.** Editing `.github/workflows/*` over HTTPS needs the
  `workflow` token scope: `gh auth refresh -h github.com -s workflow`.

`scripts/open_fix_pr.sh` checks the active account before pushing and uses a
compliant commit message (no Claude attribution, no co-author).
