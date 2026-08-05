# Fetching findings from the TCS MCP

The Tenable Cloud Security MCP exposes IaC findings through **GraphQL**
(read-only) and **UDM** (Explore). GraphQL is the validated path for this
workflow. Findings are keyed by an **account id**: `github.com/<owner>/<repo>`.

## Primary query — open findings for one repo

```graphql
{
  Findings(filter: {
    AccountIds: ["github.com/<owner>/<repo>"]
    Statuses: [Open]
  }) {
    totalCount
    nodes {
      ... on CodeFinding {
        Id
        Severity          # Critical | High | Medium | Low | Info
        Status            # Open | Closed
        Description       # policy intent — the "why", not a code snippet
        Link              # ready-made console URL; use verbatim in the PR table
        FilePath          # repo-relative path of the affected file
        Policy {
          Id
          Name            # e.g. "S3 Bucket MFA delete is not enabled"
          Description
          Category        # Data | Network | IAM | ...
        }
        Commit { BranchName Hash AuthorName }
      }
    }
  }
}
```

Call it with `mcp__TCS__graph_execute_query`.

### Notes that will bite you if ignored

- `Findings` returns a **`FindingsConnection`**, so you must go through
  `nodes { ... on CodeFinding { ... } }`. A bare `... on CodeFinding` at the top
  level fails with "parent type does not match the type condition".
- **`Remediation.Console.Steps` is null for IaC findings** and so is `Context`.
  The platform does not hand you a code fix — only the policy intent. You author
  the HCL. Don't wait for a remediation snippet that will never come.
- Always pass `Statuses: [Open]` (an enum — **unquoted**; valid values are
  `Open`, `Closed`, `Ignored`). Closed findings are already remediated;
  "fixing" them produces empty or nonsensical diffs.

## List repositories that have findings

When you don't know the exact account id, discover it:

```graphql
{
  Findings(filter: { Statuses: [Open] }) {
    nodes { ... on CodeFinding { AccountId AccountName } }
  }
}
```

Group the results by `AccountId` and let the user pick. (For large tenants,
prefer UDM `ICodeConfigurationRisk` with a group-by; see the MCP's
`udm_get_instructions`.)


## MCP under-reporting vs. the Code Scans UI

If the user points at a finding the query doesn't return, say
so — do not fabricate it.
