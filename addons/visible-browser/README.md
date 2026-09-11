# Visible browser add-on

This add-on runs headed Chromium in a virtual X display, exposes it to
Playwright through a private CDP connection, and serves a localhost-only noVNC
viewer. Start with the [main setup guide](../../README.md) for network selection,
installation, the Open WebUI connection, and the SSH tunnel.

The named profile volume may contain cookies and sessions. Treat it as
sensitive. Never publish ports 5900 or 9222. The browser is single-user and
not per-chat isolated.

## How the services fit together

| Service | Role | Networks |
| --- | --- | --- |
| `visible-browser-session` | Chromium, virtual display, CDP proxy, and noVNC | Private browser network |
| `visible-playwright` | Exposes browser tools through MCP and controls Chromium | Shares the session container's network namespace |
| `visible-browser-tools` | API-key-protected OpenAPI bridge for Open WebUI | Browser and shared Open WebUI networks |

Only noVNC is published on the host, at `127.0.0.1:6080`. The browser network is
not an egress firewall; pages can still reach destinations permitted by the host's
networking policy. Keep untrusted containers off this network.

## Manual login handoff

1. Enable only the visible browser tool server in the chat.
2. Ask the model to navigate to the login page and then wait.
3. Wait for active tool calls to finish. Open noVNC through the SSH tunnel.
4. Enter credentials and complete MFA yourself in the visible browser.
5. Tell the model it can resume, with the specific task and allowed actions.
6. Log out when the account session should no longer be available to the tools.

The human and the model share one browser. Avoid simultaneous input. Login state
persists across chats and container restarts, and may be accessible to other users
who can invoke this server. Use a dedicated account and restrict tool access.

## Inspect and recover the viewer

From this directory on the Docker host:

```bash
docker compose ps -a
docker compose logs --tail=100 visible-browser-session
docker compose logs --tail=100 visible-playwright visible-browser-tools
```

Session logs contain output from Xvfb, Chromium, the CDP proxy, x11vnc, and noVNC.
Look for processes repeatedly exiting. A running session container alone does
not prove that Chromium or the viewer is ready.

If the session is stuck, stop active tool use, then restart the stack together:

```bash
docker compose down
docker compose up -d
```

This interrupts the viewer and active automation but retains the profile volume.
Wait for startup, reconnect noVNC, and repeat the main guide's example.com test.
Do not delete the profile as the first troubleshooting step.

## Start with a fresh profile while keeping the old one

1. Stop the add-on with `docker compose down` without `--volumes`.
2. Record the current `VISIBLE_BROWSER_PROFILE_VOLUME` from `.env` privately.
3. Set it in `.env` to a new, unused volume name, such as
   `open-webui_visible-browser-profile-fresh`. Check existing names with
   `docker volume ls` and choose another name if it already exists.
4. Run `docker compose up -d` and verify that Chromium starts with a fresh profile.

If you exported `VISIBLE_BROWSER_PROFILE_VOLUME` in the shell, unset it before
starting so it does not override `.env`. To return to the old profile, stop the
stack, restore its previous volume name in `.env`, and start again. Do not run
two browser instances against the same profile volume.

The old volume still contains sensitive browser data. Switching profiles does not
erase it or revoke its sessions. Keep track of retained volumes and remove them
only after verifying their exact names and deciding that their data is no longer
needed. Avoid broad volume-pruning commands for profile cleanup.
