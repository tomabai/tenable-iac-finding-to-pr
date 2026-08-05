# Tenable IaC Finding → PR

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that turns open
Infrastructure-as-Code (IaC) security findings from **Tenable Cloud Security (TCS)**
into reviewed, mergeable GitHub pull requests.

The platform gives you the *intent* of a fix (the policy name + description); the
skill authors the minimal Terraform change itself, then opens a PR whose body links
every fix back to the finding in the Tenable console.

## What it does

- **Verifies the TCS MCP is connected** before doing anything, and prints install
  steps if it isn't.
- **Fetches open IaC findings** for a repository (account id
  `github.com/<owner>/<repo>`) via the TCS MCP, filtering to `Open` only. If you
  don't name a repo, it asks which one — or lets you sweep all repos that have
  findings.
- **Surfaces the findings** in a compact table (severity, policy, resource/file,
  a link back to the platform) so you see exactly what will change before any code
  is touched.
- **Asks how to split the work** — one combined PR, or one PR per finding.
- **Authors minimal Terraform fixes** targeting the exact named resource, following
  a strict set of rules (minimal diff, never rename or remove resources, never
  fabricate values, preserve formatting).
- **Opens the PR(s)** with a findings table and per-finding `Risk` /
  `Remediation Applied` sections grounded in the policy.

## How it works

The skill is interactive by design — it never opens a PR before you've seen the
findings and chosen how to split them.

1. **Connect** — confirms the `TCS` MCP server is reachable (`mcp__TCS__*` tools).
2. **Fetch** — GraphQL query against the TCS MCP for `CodeFinding` records
   (`Id`, `Severity`, `Status`, `Description`, `Link`, `FilePath`, `Policy`).
3. **Review** — presents the findings and asks how to batch them.
4. **Fix** — reads each affected file, matches the resource by exact name, and
   applies the minimal change the policy requires.
5. **PR** — creates the branch, commits, pushes, and opens the pull request(s),
   handling common `gh`/`git` gotchas (account flips, stale credential helpers).

## Requirements

- Claude Code
- The **Tenable Cloud Security MCP server** connected in your session. See
  [`references/mcp-setup.md`](references/mcp-setup.md) for install and onboarding
  notes.
- `gh` (GitHub CLI) and `git`, authenticated for the target repo.
- `terraform` (optional, for `fmt`/`validate` before opening the PR).

## Installation

Copy this directory into your Claude Code skills folder:

```bash
cp -r tenable-iac-finding-to-pr ~/.claude/skills/
```

Then invoke it in a session with `/tenable-iac-finding-to-pr`, or just ask Claude
to "fix my Tenable IaC findings and open a PR."

## Layout

```
SKILL.md                     the skill definition and step-by-step workflow
references/
  queries.md                 GraphQL queries for fetching findings
  mcp-setup.md               TCS MCP install + onboarding notes
  fix-rules.md               rules for authoring safe, minimal fixes
  pr-template.md             the exact PR body/title/commit template
scripts/
  open_fix_pr.sh             branch + commit + push + open PR (with guards)
```

## License

[MIT](LICENSE)
