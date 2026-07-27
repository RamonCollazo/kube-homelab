# greencloud

Host-level Docker Compose apps for the GreenCloudVPS KVM. Not part of the Flux tree;
these run directly on the machine and are converged by a systemd timer that pulls this
repo.

Purpose: host a **self-hosted Omni** instance to replace the Sidero SaaS instance
currently managing the `homelab-staging` Talos cluster.

## Host

| Property | Value |
|---|---|
| OS | Ubuntu 24.04 LTS |
| CPU / RAM | 4 vCPU, 7.7 GB |
| Disk | 60 GB |
| Login | `ramon`, key auth only, root and password auth disabled |
| Firewall | ufw, default deny inbound |

## Layout

```
machines/greencloud/
├── .sops.yaml            age recipient for this machine's secrets
├── deploy.sh             converges every app under apps/
├── deploy/               systemd unit + timer + tool installer, run once by hand
└── apps/
    └── traefik/          TLS termination and ACME, plus its socket proxy
        ├── docker-compose.yaml
        └── traefik.yaml  Traefik static configuration
```

`socket-proxy` lives in Traefik's compose project rather than its own directory because it
is a privilege-separation sidecar, not an independent app: it exists only to keep Traefik
away from the Docker socket and has no purpose without it.

An app that needs secrets gets a SOPS-encrypted `secrets.env` next to its compose file,
matching how `apps/staging/<app>/secrets.yaml` works elsewhere in this repo. `deploy.sh`
decrypts each app's secrets separately, so an app only ever sees its own. Apps with no
`secrets.env` are converged without one.

**Nothing here currently has secrets.** Traefik uses the HTTP-01 ACME challenge, which
needs no credentials. The scaffolding stays because Omni will need it.

Traefik's static configuration lives in `traefik.yaml` rather than as `command:` flags.
Traefik treats its three static configuration sources (file, CLI arguments, environment
variables) as mutually exclusive, so the compose file carries no `command:` at all.

That file also does not expand environment variables, which is why the hostname, ACME
email, and CA server are literals in it. That is no loss: it means switching the CA server
from staging to production is a commit rather than an untracked edit on the host.

Each directory under `apps/` is an independent Compose project. They share the external
Docker network `edge`, which `deploy.sh` creates if missing. Traefik discovers the others
through the Docker provider, so a new app only needs `traefik.*` labels and membership of
`edge`.

`deploy.sh` hashes every file in an app directory except `docker-compose.yaml` and
`secrets.env`, exporting it as `CONFIG_HASH`. A compose file that mounts configuration
should carry `config.hash=${CONFIG_HASH:-none}` as a label. Without it `docker compose up
-d` sees an unchanged compose config and leaves the container running, so an edit to a
mounted file like `traefik.yaml` would never take effect. This is the same trick as the
`configMapGenerator` rollout convention used in the cluster.

## Continuous deployment

`greencloud-deploy.timer` fires every 5 minutes and runs `greencloud-deploy.service`,
which does `git pull --ff-only` followed by `deploy.sh`. Merging to `main` converges the
host within 5 minutes. Rolling back is `git revert`.

The clone is anonymous HTTPS. This repo is public, so the host needs no deploy key, no
token, and no credentials of any kind. Pulls are read-only by construction: a push fails
with `could not read Username for 'https://github.com'`, so a compromised VPS cannot write
back to the repo.

Renovate already watches this repo and picks up `docker-compose.yaml` image tags through
the default docker-compose manager, so version bumps arrive as PRs like everything else.

## First-time setup on the host

```bash
git clone https://github.com/RamonCollazo/kube-homelab.git ~/kube-homelab
cd ~/kube-homelab/machines/greencloud

sudo ./deploy/install-tools.sh

# restore the age private key to ~/.config/sops/age/keys.txt, mode 600

sudo cp deploy/greencloud-deploy.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now greencloud-deploy.timer
```

`install-tools.sh` pins the `sops` version; Renovate tracks it through a custom manager in
`renovate.json`, so upgrades arrive as PRs like everything else.

Check on it with `systemctl list-timers greencloud-deploy.timer` and
`journalctl -u greencloud-deploy.service -n 50`.

## Secrets

No app currently needs a secret. The machinery below is set up and ready for the first one
that does, which will be Omni.

An app's `secrets.env` is SOPS-encrypted with an age key and committed to this repo,
matching how the clusters handle theirs. SOPS encrypts dotenv values while leaving keys
readable, so diffs still show which variable changed. `deploy.sh` runs each app's `docker
compose` under `sops exec-env`, so decrypted values reach it through the environment and
plaintext never touches disk.

This machine has **its own age recipient**, distinct from the cluster keys in
`clusters/*/.sops.yaml`. A compromise of the VPS must not expose cluster secrets.

```
age1tmvafqxwdw0nmpw9pryhgmpnuxjm9y6wztnas048zf3zvjgm29fsjls3gv
```

The private key lives at `~/.config/sops/age/keys.txt` on the host, mode 600. **Back it up
somewhere off the machine.** Without it every encrypted file here becomes unrecoverable.
To edit secrets you need the same key wherever you run `sops`.

```bash
sops apps/<app>/secrets.env      # opens $EDITOR, re-encrypts on save
sops -d apps/<app>/secrets.env   # print decrypted, for debugging
```

A `sops-encrypted` pre-commit hook refuses to commit a `secrets.env` that is not
encrypted, because this repo is public and that mistake is unrecoverable once pushed.

## TLS

Traefik obtains certificates from Let's Encrypt over the HTTP-01 challenge on port 80. No
credentials are involved, which is why this machine has no secrets yet.

The tradeoff is that **HTTP-01 cannot issue wildcards**; that is an ACME constraint, not a
Traefik one. The only thing here that would want `*.omni.raymondcollazo.com` is Omni's
workload proxying, which exposes cluster services at `<id>-<name>.omni.<domain>`. That
overlaps with what Cloudflare tunnels plus Authentik already do, so it is not being used.
Enabling it later means switching this resolver to DNS-01, which needs a Cloudflare API
token with `Zone:DNS:Edit` and an `apps/traefik/secrets.env` to hold it.

Port 80 must stay reachable permanently, not just at first issuance, because renewals use
the same challenge.

**Certificates are only requested when a router asks for one.** Setting `domains` on the
`websecure` entrypoint does not trigger issuance by itself; it only supplies defaults to
routers using that entrypoint. Until an app declares a router, Traefik serves its
self-signed `TRAEFIK DEFAULT CERT` and never contacts the CA. That is the expected state
here right now, not a fault.

Routing labels belong on the app that owns the route, never on Traefik itself. An app
requests its certificate by declaring a router, for example:

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.omni.rule=Host(`omni.raymondcollazo.com`)"
      - "traefik.http.routers.omni.entrypoints=websecure"
      - "traefik.http.routers.omni.tls.certresolver=letsencrypt"
```

Issuance over HTTP-01 has been validated end to end against the Let's Encrypt staging
endpoint, including confirming that the port 80 redirect does not interfere with the
challenge.

The `web` entrypoint both serves the ACME challenge and redirects to HTTPS. Traefik's docs
state "Redirection is fully compatible with the `HTTP-01` challenge", and this is running
v3. If certificates ever fail to issue with challenge requests appearing to be redirected,
that combination is the first thing to suspect: `traefik/traefik#7825` reported it on v2.4,
though the issue was frozen due to age without resolution. The fallback is to drop the
`redirections` block from the `web` entrypoint, leaving port 80 serving only ACME.

`caServer` in `traefik.yaml` points at Let's Encrypt **production**. Issuance was validated
against the staging endpoint first:

```yaml
caServer: https://acme-staging-v02.api.letsencrypt.org/directory
```

When switching between the two, delete `apps/traefik/certs/acme.json` or Traefik keeps
serving the certificate it already holds. That file is root-owned mode 600, which is
correct since it contains private keys, so removing it needs `sudo`.

The ACME email receives expiry notices, so it must be an address someone actually reads.
Certificate expiry is the failure mode that bites hardest here: it surfaces as cryptic
behaviour during node reboots rather than an obvious outage.

Certificates deliberately live with Traefik rather than inside Omni. Omni runs without TLS
on the internal network and Traefik terminates it, so renewals never restart Omni. That
matters because siderolabs/omni#2524 reports machines failing to reconnect after an Omni
restart.

## Hardening notes

`no-new-privileges`, a healthcheck against Traefik's `/ping`, and `json-file` log rotation
(10 MB x 3) are set. Rotation matters because `accessLog` writes to stdout and this is a
public endpoint on a 60 GB disk.

**Traefik never touches the Docker socket.** Mounting it `:ro` is not a security boundary:
that only prevents modifying the socket *file*, while every Docker API call still works,
including container creation. Since Traefik is the internet-facing process here, that would
make a compromise of it equivalent to host root.

Instead `socket-proxy` holds the socket and exposes a filtered API to Traefik over the
`socket` network, which is `internal: true`. Only `CONTAINERS` and `NETWORKS` are enabled
and `POST` is off, so the Docker provider gets exactly what it needs and nothing else.
Verified against the running pair:

| Request | Result |
|---|---|
| `GET /containers/json` | 200 |
| `GET /networks` | 200 |
| `POST /containers/create` | 403 |
| `POST /containers/<id>/stop` | 403 |
| `GET /images/json` | 403 |
| `GET /secrets` | 403 |

If a future app needs the Docker provider, put it on the `socket` network rather than
mounting the socket.

The dashboard runs with `api.insecure: true`, which means no authentication, but it is
published on `127.0.0.1:8080` only. Reaching it requires an SSH tunnel. That is a
deliberate trade for a single-admin box, not an oversight.

## Ports

| Port | Purpose |
|---|---|
| 80 | ACME HTTP-01 challenge, and redirect to 443. Must stay open for renewals |
| 443 | Omni UI and API |
| 8090 | Omni SideroLink gRPC, Talos nodes connect here |
| 8100 | Omni Kubernetes proxy |
| 50180/udp | SideroLink WireGuard, published by Omni directly, not proxied |
| 127.0.0.1:8080 | Traefik dashboard, loopback only, reach it over an SSH tunnel |

Nothing but 22 is open in ufw yet. Open the rest when the corresponding app is deployed.

## Not yet here

The Omni service itself. It needs an account ID, a GPG key for etcd encryption, an initial
admin user, and a decision on the identity provider. Traefik stands alone and is worth
verifying first.
