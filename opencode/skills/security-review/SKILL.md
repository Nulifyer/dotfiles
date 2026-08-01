---
name: security-review
description: Use when reviewing security, auth, secrets, injection, SSRF, path traversal, unsafe shell commands, dependency risk, or permission boundaries.
---

# Security Review

Review trust boundaries first. State concrete exploit path or data exposure. Avoid vague security advice.

## Checklist

Inputs:

- SQL, shell, template, LDAP, XML, YAML, regex, path, and URL injection.
- File paths with `..`, symlinks, absolute paths, archive extraction, and glob expansion.
- URLs with internal IPs, localhost, cloud metadata, redirects, DNS rebinding, and non-HTTP schemes.
- User-controlled headers, cookies, tokens, and callback URLs.

Auth and authorization:

- Missing authentication.
- Confused user/account/tenant ownership.
- Server-side trust in client-provided role, ID, or price.
- Token expiry, audience, issuer, replay, and refresh handling.

Secrets:

- Hardcoded keys.
- Logging secrets or PII.
- Writing secrets to temp files, caches, traces, or error messages.
- Leaking environment variables.

Execution:

- Shell command construction.
- Destructive commands.
- Unsafe package scripts.
- Eval, dynamic import, deserialization, and template execution.

Web:

- XSS, CSRF, CORS, open redirects.
- Cookie flags and session fixation.
- Upload validation and content sniffing.

## Output

Findings must include:

- Trust boundary.
- Attacker-controlled input.
- Impact.
- Minimal fix.

Use plain English for high-risk warnings. Do not compress if it could make security meaning ambiguous.
