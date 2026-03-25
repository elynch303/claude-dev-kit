# Security

These rules apply to all files. When in doubt, err on the side of caution.

- Never commit secrets, API keys, tokens, or credentials — use environment variables and `.gitignore`
- Validate **all** input at system boundaries (API routes, CLI args, file uploads, webhooks) before processing
- Never expose internal error messages, stack traces, or DB query details to API clients
- Use parameterized queries or an ORM — never concatenate user input into raw SQL strings
- Sanitize user-supplied content before rendering in HTML to prevent XSS
- Authentication checks must happen before any business logic — never after
- Reject unexpected fields in API payloads using strict schema validation (Zod `strict()`, Pydantic `model_config = ConfigDict(extra="forbid")`)
- Log security events (failed auth, rate-limit hits, permission denials) but never log sensitive values (passwords, tokens, PII)
- Use `httpOnly` + `Secure` + `SameSite=Strict` cookie attributes for session tokens
- Apply the principle of least privilege: request only the permissions/scopes your code actually needs
