# PR template

Follow this exactly. It merges the platform's remediation-PR contract (the
verbatim opening line, the `### Risk` / `### Remediation Applied` sections, the
conventional commit) with a findings **table** that links each finding back to
the Tenable console.

**The PR body contains ONLY the sections defined below — nothing more.** Do not
append environment or `terraform fmt`/`validate` notes, an "Additional
observations" section, out-of-scope findings the scan didn't return, or any
other commentary. Anything like that goes to the user in chat, not the PR.

## Fields

- **prTitle** — concise and specific, ~6–12 words, naming the fix.
  - One finding: `Enable MFA delete on S3 bucket risky_bucket`
  - Combined:   `Fix 4 Tenable Cloud Security IaC findings in main.tf`
- **commitMessage** — a single conventional-commit line, ≤70 chars. No "Claude
  Code" attribution, no `Co-Authored-By`.
  - `fix: enable MFA delete on S3 bucket risky_bucket`
  - `fix: remediate 4 tenable iac findings in main.tf`
- **prBody** — Markdown, structured as below.

## prBody structure

The **first line is verbatim** and never changes:

```
Automated remediation for a security finding detected by Tenable Cloud Security.
```

Then a findings table (one row per finding in this PR), using each finding's
`Link` field for the platform link:

```
| Severity | Policy | Resource / File | Finding |
|----------|--------|-----------------|---------|
| High | Security Group unrestricted inbound internet access | `aws_security_group.risky_sg` (`main.tf`) | [06aaa1a1](<Link>) |
| Medium | S3 Bucket is not encrypted with KMS | `aws_s3_bucket.risky_bucket` (`main.tf`) | [d0e7937f](<Link>) |
```

Then, **for each finding**, a subsection grounded in that finding's policy —
no generic filler:

```
## <Policy name> — `<resource>`

### Risk
<The specific risk this finding represents, grounded in the policy description.>

### Remediation Applied
<The specific Terraform change made to resolve it, e.g. which resource/attribute
and why. If you could not fix it, say so here and that it needs manual review —
do not leave a silent gap.>
```

Close with the review note (verbatim intent, wording can flex slightly):

```
---
_This fix was generated automatically and should be reviewed before merging._
```

## Single-finding PR (one-PR-per-finding mode)

Same shape, but the table has a single row and there is exactly one
`### Risk` / `### Remediation Applied` pair. You may drop the `## <Policy name>`
heading since there's only one finding.

## Worked example — combined PR (matches the validated PoC)

```markdown
Automated remediation for a security finding detected by Tenable Cloud Security.

| Severity | Policy | Resource / File | Finding |
|----------|--------|-----------------|---------|
| High | Security Group unrestricted inbound internet access | `aws_security_group.risky_sg` (`main.tf`) | [06aaa1a1](https://app.tenable.com/customer/Risks/Code/Open#risk/06aaa1a1-ce18-44a6-aec6-b12268e5edab) |
| Medium | S3 Bucket is not encrypted with KMS | `aws_s3_bucket.risky_bucket` (`main.tf`) | [d0e7937f](https://app.tenable.com/customer/Risks/Code/Open#risk/d0e7937f-94fb-4f1e-a758-7b09fe9e341e) |
| Medium | S3 Bucket MFA delete is not enabled | `aws_s3_bucket.risky_bucket` (`main.tf`) | [d078cc6a](https://app.tenable.com/customer/Risks/Code/Open#risk/d078cc6a-41ae-47bb-b673-92944adf9405) |
| Medium | S3 Bucket encryption in transit is not enabled | `aws_s3_bucket.risky_bucket` (`main.tf`) | [c7635f0b](https://app.tenable.com/customer/Risks/Code/Open#risk/c7635f0b-b522-4825-933a-13cd9b78a561) |

## Security Group unrestricted inbound internet access — `aws_security_group.risky_sg`

### Risk
The security group allowed inbound SSH (port 22) from `0.0.0.0/0`, exposing the
management port to the entire internet and inviting brute-force and exploit
attempts against any instance attached to the group.

### Remediation Applied
Introduced an `allowed_ssh_cidrs` variable (default `10.0.0.0/8`) and pointed the
port-22 ingress rule at it instead of `0.0.0.0/0`, so SSH is reachable only from
approved networks. Egress and web ports were left unchanged.

## S3 Bucket is not encrypted with KMS — `aws_s3_bucket.risky_bucket`

### Risk
Objects were stored without KMS encryption at rest, so a compromise of the
underlying storage or a misassigned permission could expose bucket data with no
additional key barrier.

### Remediation Applied
Added an `aws_kms_key` (with key rotation enabled) and an
`aws_s3_bucket_server_side_encryption_configuration` that applies `aws:kms` by
default, with `bucket_key_enabled = true` to reduce KMS request cost.

## S3 Bucket MFA delete is not enabled — `aws_s3_bucket.risky_bucket`

### Risk
Without MFA delete, a single compromised credential could permanently delete
object versions or disable versioning, removing the safety net against
accidental or malicious data loss.

### Remediation Applied
Set `mfa_delete = "Enabled"` alongside `status = "Enabled"` in
`aws_s3_bucket_versioning`. Note: activating MFA delete requires the root account
and an MFA device at apply time — this is not purely declarative.

## S3 Bucket encryption in transit is not enabled — `aws_s3_bucket.risky_bucket`

### Risk
The bucket accepted plain-HTTP requests, allowing data in transit to be
intercepted or tampered with on the network path.

### Remediation Applied
Added an `aws_s3_bucket_policy` that denies all `s3:*` actions when
`aws:SecureTransport` is `false`, forcing HTTPS-only access.

---
_This fix was generated automatically and should be reviewed before merging._
```
