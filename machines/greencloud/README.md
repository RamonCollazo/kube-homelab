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
├── .env.example          template; the real .env is gitignored and lives on the host
├── deploy.sh             converges every app under apps/
├── deploy/               systemd unit + timer, installed once by hand
└── apps/
    └── traefik/          TLS termination and ACME for everything else
        ├── docker-compose.yaml
        └── traefik.yaml   Traefik static configuration
```

Traefik's static configuration lives in `traefik.yaml` rather than as `command:` flags.
Traefik treats its three static configuration sources (file, CLI arguments, environment
variables) as mutually exclusive, so the compose file carries no `command:` at all.

That file also does not expand environment variables, which is why the hostname, ACME
email, and CA server are literals in it. `CF_DNS_API_TOKEN` is the exception: the ACME DNS
provider reads its credentials directly from the process environment, bypassing the static
configuration parser, so it stays a container environment variable.

Each directory under `apps/` is an independent Compose project. They share the external
Docker network `edge`, which `deploy.sh` creates if missing. Traefik discovers the others
through the Docker provider, so a new app only needs `traefik.*` labels and membership of
`edge`.

## Continuous deployment

`greencloud-deploy.timer` fires every 5 minutes and runs `greencloud-deploy.service`,
which does `git pull --ff-only` followed by `deploy.sh`. Merging to `main` converges the
host within 5 minutes. Rolling back is `git revert`.

Renovate already watches this repo and picks up `docker-compose.yaml` image tags through
the default docker-compose manager, so version bumps arrive as PRs like everything else.

## First-time setup on the host

```bash
git clone git@github.com:RamonCollazo/kube-homelab.git ~/kube-homelab
cp ~/kube-homelab/machines/greencloud/.env.example ~/kube-homelab/machines/greencloud/.env
$EDITOR ~/kube-homelab/machines/greencloud/.env

sudo cp ~/kube-homelab/machines/greencloud/deploy/greencloud-deploy.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now greencloud-deploy.timer
```

Check on it with `systemctl list-timers greencloud-deploy.timer` and
`journalctl -u greencloud-deploy.service -n 50`.

## Secrets

`.env` is gitignored and placed on the host by hand, matching the existing `mise.toml`
convention of `_.file = ".env"` for workspace-local secrets. This repo is public, so
nothing secret belongs in it.

`CF_DNS_API_TOKEN` needs `Zone:DNS:Edit` on the `raymondcollazo.com` zone. It is used only
for ACME DNS-01 challenges.

## TLS

Traefik obtains certificates from Let's Encrypt over DNS-01 through Cloudflare. DNS-01 is
used rather than HTTP-01 for two reasons: it issues the wildcard needed by Omni's workload
proxying, and it validates without any inbound connection, so certificates can be obtained
before the firewall is opened.

`caServer` in `traefik.yaml` points at the Let's Encrypt **staging** endpoint. Verify
issuance against staging first, then switch to production by committing:

```yaml
caServer: https://acme-v02.api.letsencrypt.org/directory
```

Delete `apps/traefik/certs/acme.json` when switching, or Traefik will keep serving the
staging certificate.

The ACME email receives expiry notices, so it must be an address someone actually reads.
Certificate expiry is the failure mode that bites hardest here: it surfaces as cryptic
behaviour during node reboots rather than an obvious outage.

Certificates deliberately live with Traefik rather than inside Omni. Omni runs without TLS
on the internal network and Traefik terminates it, so renewals never restart Omni. That
matters because siderolabs/omni#2524 reports machines failing to reconnect after an Omni
restart.

## Ports

| Port | Purpose |
|---|---|
| 80 | redirect to 443 |
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
