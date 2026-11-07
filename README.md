# infra

An extendable base to set up AlmaLinux servers: a VPS today, the Proxmox VMs
later. **Ansible** configures the host (users, SSH, tools, Docker, Tailscale).
The **services** are plain `docker compose` stacks, deployed by hand.

## Layout

```
ansible/
  inventory/            hosts.yml (who exists), host_vars/<host>.yml (how to reach it, per-host vars)
  playbooks/            site.yml runs everything; each piece also runs alone
  roles/                user, ssh, swap, common_tools, auto_updates, docker, tailscale, telegram, backup
  .env.example          secrets and site values read by Ansible (copy to .env, not committed)
docker/                 compose stacks: caddy, headscale, mqtt, vaultwarden
scripts/                ca-new.sh / ca-sign.sh, a private CA for TLS
```

## Extending it

- **A new host:** add it under a group in `ansible/inventory/hosts.yml` and give
  it `ansible/inventory/host_vars/<name>.yml` (at least `ansible_host`).
  Per-host switches live there too, e.g. `tailscale_exit_node: true`.
- **A new piece of setup:** a role in `ansible/roles/`, a playbook in
  `ansible/playbooks/`, and one line importing it from `site.yml`.
- **A new service:** a folder in `docker/` with its `compose.yml`, deployed by
  hand (see below). Ansible stops at "Docker is ready".

## IPs, Tailscale and the first run

The inventory addresses hosts by their **Tailscale name** (`ansible_host: cloud`,
resolved by MagicDNS to a `100.64.x.x` address). That only works **after** the
host has joined the tailnet, and public SSH (22) is closed in the provider
firewall once it has.

So on a fresh server there is no Tailscale yet, and the first runs go to the
**public IP** instead, with port 22 open in the provider firewall for a while:

```bash
cd ansible && uv sync
uv run ansible-galaxy collection install ansible.posix
cp .env.example .env            # set TS_LOGIN_SERVER

# 1. root with password, once. Creates your admin users, the hostname and swap.
uv run --env-file .env ansible-playbook playbooks/bootstrap.yml -u root -k -e ansible_host=<public-ip>
ssh alex@<public-ip>            # check that key login and sudo work

# Ansible connects as your local user, which is one of the admins (alex). If
#    yours has another name, add -u <admin-name>.
# 2. everything else: SSH hardening (closes root and passwords), tools,
#    updates, Docker, Tailscale (installed, not joined yet).
uv run --env-file .env ansible-playbook playbooks/site.yml --check --diff -e ansible_host=<public-ip>
uv run --env-file .env ansible-playbook playbooks/site.yml -e ansible_host=<public-ip>
```

Joining the tailnet needs Headscale running, and Headscale is one of the
services on this very server, so it comes after step 2:

```bash
# 3. deploy Headscale by hand (see "Services"), set TS_AUTHKEY in ansible/.env, then:
uv run --env-file .env ansible-playbook playbooks/tailscale.yml -e ansible_host=<public-ip>
```

Once the node is on the tailnet, close port 22 in the provider firewall. From
then on drop the `-e ansible_host=...`: the inventory name works, as long as
Tailscale is running on **your** machine.

```bash
uv run --env-file .env ansible-playbook playbooks/site.yml --check --diff
uv run --env-file .env ansible-playbook playbooks/site.yml
```

If the tailnet is down you can't reach the server: keep the provider's web
console at hand, or open 22 again for a moment.

## Secrets for Ansible

`ansible/.env` is not committed; `uv run --env-file .env` loads it, so there is
nothing to `source`. Copy `ansible/.env.example` and fill in:

- `TS_LOGIN_SERVER`: public URL of Headscale.
- `TS_AUTHKEY`: pre-auth key, only to join a new node.
- `RESTIC_PASSWORD`: password of the backup repository (keep a copy elsewhere).
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`: bot for notifications (optional).

## Backups

Every night (05:00, set per host with `backup_time` in `host_vars/<host>.yml`) a
systemd timer runs `docker-backup`: it stops every stack under `/srv/docker`,
copies the data to a local restic repository (`/srv/backup/restic`), starts the
stacks again and prunes old snapshots. Stopping the containers keeps databases
consistent without per-service dumps, so a new service needs nothing extra.

```bash
sudo systemctl start docker-backup.service   # backup now (stops the stacks, like the nightly one)
sudo docker-restore snapshots
sudo docker-restore restore latest /srv/docker/vaultwarden   # into /srv/backup/restore/<date>
```

Notifications go through a Telegram bot (`TELEGRAM_BOT_TOKEN` and
`TELEGRAM_CHAT_ID` in `ansible/.env`). A failed backup always notifies, quoting
the last error line, and so does a disk over `backup_disk_warn_percent` (80).
Verbose mode, enabled per host with `backup_notify_verbose: true` in
`host_vars/<host>.yml`, sends "Backup Started" and edits that same message into
the result. Without the credentials nothing is sent.

Restores never overwrite live data: copy back what you need. The repository
password is `RESTIC_PASSWORD` in `ansible/.env`: keep a copy in your password
manager. The repository is on the same disk, so it covers mistakes and bad
updates, not losing the server: copy it elsewhere (`restic copy`) for that.

## Services (`docker/`)

Each stack is deployed by hand on the server, under `/srv/docker/<service>/`,
as the `docker` user (`sd` is the alias for `sudo su - docker`):

```bash
docker compose up -d
```

- **The configs in the repo are examples**, with placeholder domains and IPs
  (`example.com`, `203.0.113.10`). Copy each one, drop `.example` from the name
  and put your real values in. The real files are not committed:
  - `caddy/caddyfile/Caddyfile`: example sites, committed as is. Your real one
    (with your domains) lives only on the server.
  - `caddy/.caddy.env.example` and `vaultwarden/.vaultwarden.env.example`.
  - `headscale/back/config/config.example.yaml` (Headscale) and
    `headscale/front/config/config.example.yaml` (Headplane).
- Real config and secrets (`.env` files, data, certificates) are not committed.
  The folders are kept with `.gitkeep`.
- Update with `docker compose pull && docker compose up -d`. Avoid `down` on
  Headscale: it briefly cuts the tailnet.
- Helper scripts live next to each compose (`caddy-reload.sh`, `mqtt-passwd.sh`,
  `gen-admin-token.sh`, `headscale-apikey.sh`).
