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

## Before you start

- Linux host with Docker Engine and Compose v2.
- Git, Bash, and OpenSSL on that host. The setup scripts use OpenSSL to generate
  a separate random API key for each add-on.
- An Open WebUI container attached to a user-defined Docker network.
- Administrator access to Open WebUI to add a server-side tool connection.
- An Open WebUI model/provider that supports tool calling.
- SSH access to the Docker host if using the visible/noVNC add-on.

This repository adds browser tools to an existing Open WebUI installation;
it does not install Open WebUI or a model. Docker commands below run on the
Docker host. Only the SSH tunnel and viewing noVNC run on your workstation.

Check that your user can reach Docker before continuing:

```bash
docker info
docker compose version
git --version
openssl version
```

If Docker reports permission denied, fix access using your host's Docker
installation instructions before running `setup.sh`.

## 1. Get the repository

Clone the public repository on your Docker host:

```bash
git clone https://github.com/AngelN-Halo/open-webui-browser-workspace.git open-webui-browser-workspace
cd open-webui-browser-workspace
```

If you already have a checkout, use its directory instead. The add-on commands
below assume you start at the repository root.

## 2. Find your Open WebUI network

List containers and find the one running Open WebUI:

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

Replace `OPEN_WEBUI_CONTAINER` with that container's name:

```bash
docker inspect OPEN_WEBUI_CONTAINER --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}'
docker network ls
```

Use an existing user-defined bridge network from that container's network list.
The default in this project is `open-webui_default`, but your installation may
use another name. Do not use Docker's built-in `bridge`, `host`, or `none` network.
If Open WebUI has no user-defined bridge network, configure one in its deployment
first. For network setup details, see [Docker's Compose networking guide](https://docs.docker.com/compose/how-tos/networking/).

The selected network must already exist. Set its name before running setup
(replace `YOUR_NETWORK_NAME`):

```bash
export OPEN_WEBUI_NETWORK=YOUR_NETWORK_NAME
```

The setup script writes this value to `.env`. If `.env` already exists, the
script leaves it unchanged; edit its `OPEN_WEBUI_NETWORK` value yourself.
An exported variable overrides the value in `.env` during Compose commands, so
keep them consistent or run `unset OPEN_WEBUI_NETWORK` after setup to use `.env`.

## 3. Choose and start one add-on

| Add-on | Best for | Browser state | Viewer |
| --- | --- | --- | --- |
| Headless | Page navigation and automation without a desktop | Isolated mode; no persistent profile volume | None |
| Visible | Watching automation and completing logins manually | Persistent profile in a Docker volume | noVNC over SSH |

Do not enable both browser tool servers in the same chat: they expose similar
operation names, but only the visible add-on's browser appears in noVNC.
These configurations use fixed Compose project names; multiple independent
instances require additional configuration.

### Headless

```bash
cd addons/headless-browser
./setup.sh
```

Setup creates a private `.env` with a random key and validates Compose; it does
not start containers or verify that the external network exists. Review `.env`
locally, then start:

```bash
docker compose pull
docker compose up -d
docker compose ps -a
docker compose logs --tail=100
```

Expect `playwright` and `browser-tools` to stay running. Continue to step 4.

### Visible browser with noVNC

```bash
cd addons/visible-browser
./setup.sh
```

Review `.env` locally. `VISIBLE_BROWSER_PROFILE_VOLUME` names the persistent
Docker volume; choose an unused name for a fresh profile. The first build
downloads Chromium and desktop dependencies and may take several minutes.

```bash
docker compose build visible-browser-session
docker compose pull visible-playwright visible-browser-tools
docker compose up -d
docker compose ps -a
docker compose logs --tail=100
```

Expect `visible-browser-session`, `visible-playwright`, and
`visible-browser-tools` to stay running. Startup order is configured, but there
are no readiness health checks; give Chromium time to start before testing.

### Configuration reference

| Variable | Purpose | Default / setup behavior |
| --- | --- | --- |
| `BROWSER_TOOLS_API_KEY` | Bearer key protecting the OpenAPI bridge | Setup generates a 32-byte random key encoded as hex |
| `OPEN_WEBUI_NETWORK` | Existing network shared with Open WebUI | `open-webui_default` |
| `VISIBLE_BROWSER_PROFILE_VOLUME` | Visible browser's persistent profile volume | `open-webui_visible-browser-profile` |

The last variable applies only to the visible add-on. `.env.example` documents
the fields; its `replace-with-a-random-key` value is not a usable production
secret. Use `setup.sh` to generate your key. Keep `.env` private and out of Git.

## 4. Connect the tools to Open WebUI

In Open WebUI's administrator settings, find **External Tools / Tool Servers**
(the label varies by version), add a server-side connection, and select
**OpenAPI**. Use the values for your chosen add-on:

| Field | Headless | Visible |
| --- | --- | --- |
| Name | Browser — Headless | Browser — Visible |
| Base URL | `http://browser-tools:8000` | `http://visible-browser-tools:8000` |
| Schema path | `/openapi.json` | `/openapi.json` |
| Authentication | Bearer | Bearer |
| Key | Value of `BROWSER_TOOLS_API_KEY` in headless `.env` | Value of `BROWSER_TOOLS_API_KEY` in visible `.env` |

If the UI asks for a complete schema URL, append `/openapi.json` to the base URL.
Paste only the key value into the Bearer key field. Save and use the connection
verification control if available. Enable the chosen server's tools in a chat
with a model that supports tool calling.

These Docker service names are reachable from the Open WebUI backend on the
shared network. They are not workstation URLs. A personal/direct tool connection
that runs from your web browser cannot reach them. Use the administrator-managed
server-side connection described in the [Open WebUI integration guide](https://docs.openwebui.com/features/extensibility/plugin/tools/openapi-servers/open-webui/).

Only the authenticated bridge joins both the shared Open WebUI network and the
add-on's browser network. Browser-control services stay on the browser network.
No host ports are published for the API bridge, MCP, or CDP endpoints.

## 5. Open the visible viewer (visible add-on only)

The visible session uses headed Chromium in Xvfb. The same browser is exposed
to Playwright through a private CDP connection and shown through noVNC.

From your workstation, create an SSH tunnel to the Docker host:

```bash
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:6080:127.0.0.1:6080 USER@DOCKER_HOST
```

Then open `http://127.0.0.1:6080/vnc.html` and click **Connect**. Use a
second local port if 6080 is already in use, for example
`-L 127.0.0.1:6081:127.0.0.1:6080`, then open
`http://127.0.0.1:6081/vnc.html`. Replace `USER` and `DOCKER_HOST` with your
SSH login and host. Keep the SSH process running while using the viewer.
Docker handles the host-to-container mapping; you
do not SSH into the container. The noVNC port is bound to host loopback only.
If your browser runs on the Docker host itself, open the viewer directly without
a tunnel. The viewer has no VNC password; SSH and loopback binding protect access.

## 6. Verify the whole connection

> Open https://example.com with the browser tools. Call browser_snapshot and
> report the title and link destination. Do not log in or submit anything.

Confirm that the chat actually calls browser tools and reports **Example Domain**.
In visible mode, noVNC should show that same page. This checks the full path from
the model through Open WebUI and the bridge to Chromium.

A navigation response may return a snapshot filename. Call
`browser_snapshot` without a filename to receive the page structure inline.

## Human handoff and persistent sessions

Ask the model to navigate to a login page but not enter credentials. Pause the
agent, use noVNC to type the password and complete MFA, then resume it. Do not
have a human and the model interact simultaneously. Reset or log out of the
profile when the account context should not persist.
Closing the viewer, ending a chat, or restarting a container does not clear the
visible profile. Anyone allowed to use these tools may be able to use its logged-in
accounts. See the [visible browser guide](addons/visible-browser/README.md) for
profile switching and recovery.

## Troubleshooting

Run diagnostic commands from your chosen add-on directory. Start with:

```bash
docker compose config --quiet
docker compose ps -a
docker compose logs --tail=100
```

Use `--quiet` when validating configuration: plain `docker compose config`
prints the resolved API key. Review logs before sharing them; browser URLs,
page content, and other sensitive details may appear.

| Symptom | What to check |
| --- | --- |
| `Run ./setup.sh first` or missing key | Run setup in the selected add-on. If `.env` exists, check that its key is nonempty; setup will not overwrite it. |
| External network not found | Repeat step 2 and correct `OPEN_WEBUI_NETWORK`. The Open WebUI deployment must create the network first. |
| Open WebUI cannot resolve or connect to the bridge | Check that Open WebUI and the bridge share the selected network, both containers are running, and the connection is server-side. Use the service URL in step 4, not `localhost`. |
| `401` or `403` from the bridge | Check Bearer authentication and copy the key from the correct add-on's `.env`. If you changed it, recreate the bridge and update the saved Open WebUI connection. |
| Schema loads but tools fail | Inspect Playwright and bridge logs. Retry after Chromium finishes starting. For visible mode, check the session logs for Chromium or CDP errors. |
| Model answers without using tools | Enable the server in the chat, check access permissions, and confirm that the model/provider supports tool calling. Ask explicitly for `browser_snapshot`. |
| noVNC page will not load | Keep the SSH tunnel open, check its error output, confirm the correct local port, and check the session container is running. |
| noVNC loads but is blank or disconnected | Click Connect, wait for startup, then inspect Xvfb, Chromium, x11vnc, and noVNC logs using the visible guide. |
| Automation runs but the viewer never changes | Enable only the visible server in that chat. The headless server controls a different browser. |
| Local port 6080 already in use | Change the workstation tunnel port to 6081. If the conflict is on the Docker host, change only the host port in Compose, retain `127.0.0.1`, and update the tunnel destination. |
| Container repeatedly restarts or exits | Inspect logs and `docker compose ps -a`. Browser containers have memory and process limits; check host resources before changing limits. |

Do not publish browser-control ports or remove authentication to fix connectivity.

## Stop, restart, and update

Run these in the add-on directory. To pause and resume existing containers:

```bash
docker compose stop
docker compose start
```

To remove the add-on's containers and its Compose-managed network:

```bash
docker compose down
```

The visible profile volume is retained by default. The external Open WebUI network
is also retained. Adding `--volumes` deletes the add-on's declared volumes,
including saved browser sessions; see [Docker's down reference](https://docs.docker.com/reference/cli/docker/compose/down/).

After editing `.env` or Compose settings, apply them with `docker compose up -d`.
For the visible stack, if changes recreate the browser-session container, use
`docker compose up -d --force-recreate` to recreate all services together because
Playwright shares its network namespace. This interrupts active browser work.

To update, stop active automation and review upstream changes first. Update the
checkout with `git pull --ff-only` when your local changes are committed or otherwise
preserved. Then, for headless:

```bash
docker compose pull
docker compose up -d
```

For visible:

```bash
docker compose build --pull --no-cache visible-browser-session
docker compose pull visible-playwright visible-browser-tools
docker compose up -d --force-recreate
```

Repeat the verification task after updates. Images currently use moving tags
(`latest`, `main`, and `12-slim`), so later builds may behave differently. Pin
tested versions or image digests in Compose and the Dockerfile if you need
repeatable deployments.

To rotate an API key, generate a new value with `openssl rand -hex 32`, save it
privately in the selected `.env`, recreate the bridge with `docker compose up -d`,
and replace the key in Open WebUI. Running `setup.sh` again does not rotate it.

## Before publishing changes

```bash
git status --short --untracked-files=all
git diff --check
git diff --cached
```

Review staged content and commit history for secrets. `.gitignore` excludes local
environment files, profiles, common credentials, logs, and backups, but cannot
protect files already tracked or remove secrets from earlier commits. Keep example
values fictional. If a credential was committed, revoke or rotate it and address
the history before publishing. Never attach real browser profiles to bug reports.

## Boundaries

This is a proof-of-concept integration, not a complete agent safety system.
Prompt instructions are not technical approval gates. Website content can
contain prompt injection. Add policy enforcement, approvals, logging, and
stronger isolation before sensitive workflows or multiple users.

See [SECURITY.md](SECURITY.md) and [THIRD-PARTY.md](THIRD-PARTY.md).

## License

Original project files are MIT-licensed. Third-party images, source, and
dependencies retain their own licenses.
