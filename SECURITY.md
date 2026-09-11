# Security notes

This project gives a model the ability to control a real browser. Treat it as
an automation service, not as a security boundary.

- Keep the OpenAPI bridge and browser-control endpoints on private Docker
  networks. Do not publish port 8000, 8931, 9222, 5900, or 6080 publicly.
- Use a dedicated, least-privileged Open WebUI account and separate browser
  profile. The visible profile can contain cookies and authenticated sessions.
- Start with public, read-only tasks. Add human approval before purchases,
  messages, uploads, deletions, account changes, or other consequential actions.
- Type passwords and complete MFA/CAPTCHA yourself through noVNC. Do not put
  secrets in prompts or ask the model to repeat them.
- The visible setup is single-user/single-session. It is not per-user isolation.
- The default containers use `--no-sandbox` for compatibility. For untrusted
  tasks or stronger isolation, use a disposable VM and an egress policy.
- Website content is untrusted input. Models should ignore instructions found
  in pages that conflict with the user's task.

Report suspected security issues privately to the repository maintainer rather
than opening a public issue with credentials or exploit details.
