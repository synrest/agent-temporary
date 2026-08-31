# agent-temporary

agent-temporary 0.7.1 — small utility for explicitly bounded temporary root access on Linux or macOS.

## Contract

```text
sudo agent-temporary install --user zero
sudo agent-temporary on
sudo agent-temporary on --ttl 30m
sudo agent-temporary on --ttl 2h --persist-reboot
sudo agent-temporary off
agent-temporary status
agent-temporary version
sudo ./uninstall.sh
```

The npm distribution installs only an unprivileged setup command:

```sh
npm install -g agent-temporary
agent-temporary-setup install
agent-temporary status
agent-temporary-setup update
npm uninstall -g agent-temporary
agent-temporary-setup uninstall-system
```

`npm install` and `npm uninstall` affect only the npm package. The explicit setup
commands invoke the existing system installer or uninstaller and request administrator
privileges; they do not activate temporary access. To update the setup package, use
`npm install -g agent-temporary@latest` and then run `agent-temporary-setup update`.

Users without npm may use the version-pinned shell bootstrap:

```sh
curl -fsSL https://raw.githubusercontent.com/synrest/agent-temporary/v0.7.1/bootstrap/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/synrest/agent-temporary/v0.7.1/bootstrap/install.sh -o agent-temporary-install.sh
sh agent-temporary-install.sh
```

The bootstrap downloads and verifies the matching 0.7.1 release ZIP before
delegating system changes to the existing `install.sh`. It does not activate
temporary access. Inspect the downloaded script before running it when using the
inspect-first form.

Activation defaults to a 5-minute TTL. The allowed range is 5 minutes through 8 hours;
accepted forms are integer minutes or hours such as `30m`, `1h`, and `4h`.

On macOS, `--persist-reboot` explicitly preserves the same grant across reboot
until its original expiry. On Linux, the existing behavior remains unchanged.
Without persistence, boot revocation removes
temporary privilege.

While active, the configured user has unrestricted `NOPASSWD: ALL` sudo access.
The privilege is bounded by a local expiry supervisor and is revoked on boot.
It does not use SSH keys or `authorized_keys`, and does not require Netbot or a
remote controller to revoke access.

`status` reports state from local state/rule inspection and an exact harmless
`sudo -n /usr/bin/true` execution probe; sudo policy listing alone is not treated
as effective authority. `status --json` is accepted for machine-readable integration
(the key/value fields remain stable). State is stored root-owned under
`/var/lib/agent-temporary/`.

## Platform

Supported: Linux with an active systemd or OpenRC runtime and sudo/visudo, or
macOS with launchd and sudo/visudo. OpenRC is detected through its native runtime
state and service tools, including their standard `/sbin` locations.

Unsupported: Linux with another/unknown init system and unsupported platforms;
they fail closed and are not given a synthetic systemd setup.

## Release

Build a release artifact with:

```sh
./release.sh
```

The resulting directory contains the executable, systemd/OpenRC/launchd service definitions, `VERSION`,
`SHA256SUMS`, and a deterministic `install.sh`. It also creates
`dist/agent-temporary-X.Y.Z.zip` and its SHA-256 sidecar. The archive contains no Git metadata,
runtime state, logs, or private material; after extraction, run
`sudo ./install.sh --user zero` and the extracted source directory may be removed.
