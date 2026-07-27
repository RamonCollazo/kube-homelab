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
├── secrets.env.example   plaintext template
├── secrets.env           SOPS-encrypted, committed
├── deploy.sh             decrypts secrets, converges every app under apps/
├── deploy/               systemd unit + timer + tool installer, run once by hand
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

Secrets live in `secrets.env`, SOPS-encrypted with an age key and committed to this repo,
matching how the clusters handle theirs. SOPS encrypts dotenv values while leaving keys
readable, so diffs still show which variable changed.

`deploy.sh` re-executes itself under `sops exec-env`, so decrypted values reach `docker
compose` through the environment and plaintext never touches disk.

This machine has **its own age recipient**, distinct from the cluster keys in
`clusters/*/.sops.yaml`. A compromise of the VPS must not expose cluster secrets.

```
age1tmvafqxwdw0nmpw9pryhgmpnuxjm9y6wztnas048zf3zvjgm29fsjls3gv
```

The private key lives at `~/.config/sops/age/keys.txt` on the host, mode 600. **Back it
up somewhere off the machine.** Without it, `secrets.env` and any future encrypted file
here are unrecoverable. To edit secrets you need the same key wherever you run `sops`.

```bash
sops secrets.env      # opens $EDITOR, re-encrypts on save
sops -d secrets.env   # print decrypted, for debugging
```

`CF_DNS_API_TOKEN` needs `Zone:DNS:Edit` on the `raymondcollazo.com` zone. It is used only
for ACME DNS-01 challenges.

A `sops-encrypted` pre-commit hook refuses to commit a `secrets.env` that is not
encrypted, because this repo is public and that mistake is unrecoverable once pushed.

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
