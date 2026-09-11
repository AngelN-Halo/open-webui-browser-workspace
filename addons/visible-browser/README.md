# Visible browser add-on

This add-on runs headed Chromium in a virtual X display, exposes it to
Playwright through a private CDP connection, and serves a localhost-only noVNC
viewer. Use the root README for setup and human handoff guidance.

The named profile volume may contain cookies and sessions. Treat it as
sensitive. Never publish ports 5900 or 9222. The browser is single-user and
not per-chat isolated.
