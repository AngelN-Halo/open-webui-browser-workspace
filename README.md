# Open WebUI Browser Workspace

A small, self-hosted browser automation workspace for Open WebUI:

```text
Open WebUI → OpenAPI tool bridge (mcpo) → Playwright MCP → Chromium
                                                    └→ optional Xvfb/noVNC
```

It provides two independent Compose add-ons:

- **Headless:** `addons/headless-browser/` for normal page automation.
- **Visible:** `addons/visible-browser/` for a headed Chromium session that can
  be watched and manually controlled through noVNC over an SSH tunnel.

This repository contains no deployment secrets, private domains, profiles,
backups, or host-specific configuration.

## Requirements

- Linux host with Docker Engine and Compose v2.
- An Open WebUI container attached to a user-defined Docker network.
- An Open WebUI model/provider that supports tool calling.
- SSH access to the Docker host if using the visible/noVNC add-on.

The examples use the external network `open-webui_default`. Set
`OPEN_WEBUI_NETWORK` to the network used by your own Open WebUI container.

## Choose one add-on

Do not enable both browser tool servers in the same chat: they expose similar
operation names, but only the visible add-on's browser appears in noVNC.

### Headless

```bash
cd addons/headless-browser
./setup.sh
# Review .env, then:
docker compose pull
docker compose up -d
docker compose logs --tail=100
```

Add a server-side OpenAPI tool connection in Open WebUI:

- URL: `http://browser-tools:8000`
- Schema: `/openapi.json`
- Authentication: Bearer
- Key: `BROWSER_TOOLS_API_KEY` from `.env`

### Visible browser with noVNC

```bash
cd addons/visible-browser
./setup.sh
# Review .env, then:
docker compose build visible-browser-session
docker compose pull visible-playwright visible-browser-tools
docker compose up -d
docker compose logs --tail=100
```

Connect Open WebUI to:

- URL: `http://visible-browser-tools:8000`
- Schema: `/openapi.json`
- Authentication: Bearer
- Key: `BROWSER_TOOLS_API_KEY` from `.env`

The visible session uses headed Chromium in Xvfb. The same browser is exposed
to Playwright through a private CDP connection and shown through noVNC.

From your workstation, create an SSH tunnel to the Docker host:

```bash
ssh -N -L 6080:127.0.0.1:6080 USER@DOCKER_HOST
```

Then open `http://127.0.0.1:6080/vnc.html` and click **Connect**. Use a
second local port if 6080 is already in use, for example
`-L 6081:127.0.0.1:6080`. Docker handles the host-to-container mapping; you
do not SSH into the container. The noVNC port is bound to host loopback only.

## First safe test

> Open https://example.com with the browser tools. Call browser_snapshot and
> report the title and link destination. Do not log in or submit anything.

A navigation response may return a snapshot filename. Call
`browser_snapshot` without a filename to receive the page structure inline.

## Human handoff

Ask the model to navigate to a login page but not enter credentials. Pause the
agent, use noVNC to type the password and complete MFA, then resume it. Do not
have a human and the model interact simultaneously. Reset or log out of the
profile when the account context should not persist.

## Boundaries

This is a proof-of-concept integration, not a complete agent safety system.
Prompt instructions are not technical approval gates. Website content can
contain prompt injection. Add policy enforcement, approvals, logging, and
stronger isolation before sensitive workflows or multiple users.

See [SECURITY.md](SECURITY.md) and [THIRD-PARTY.md](THIRD-PARTY.md).

## License

Original project files are MIT-licensed. Third-party images, source, and
dependencies retain their own licenses.
