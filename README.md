# agent-temporary

Small Linux utility for explicitly bounded temporary root access on systemd or OpenRC.

## Contract

```text
sudo agent-temporary install
sudo agent-temporary on
sudo agent-temporary on --ttl 30m
sudo agent-temporary on --ttl 2h --persist-reboot
sudo agent-temporary off
agent-temporary status
agent-temporary version
```

Activation defaults to a 5-minute TTL. The allowed range is 5 minutes through 8 hours;
accepted forms are integer minutes or hours such as `30m`, `1h`, and `4h`.

`--persist-reboot` is exceptional and requires an explicit `--ttl`. It preserves
the original absolute expiry across reboot; it never resets or extends the TTL.
Without it, boot revocation removes temporary privilege.

While active, the configured user has unrestricted `NOPASSWD: ALL` sudo access.
The privilege is bounded by a local systemd expiry timer and is revoked on boot.
It does not use SSH keys or `authorized_keys`, and does not require Netbot or a
remote controller to revoke access.

`status` reports state from local state/rule inspection and identifies when root
inspection is required. State is stored root-owned under
`/var/lib/agent-temporary/`.

## Platform

Supported: Linux with systemd or OpenRC and sudo/visudo. OpenRC is detected through
its native service tools, including their standard `/sbin` locations.

Unsupported: macOS and Linux with another/unknown init system; unsupported platforms
fail closed and are not given a synthetic systemd setup.

## Release

Build a release artifact with:

```sh
./release.sh
```

The resulting directory contains the executable, systemd/OpenRC service definitions, `VERSION`,
`SHA256SUMS`, and a deterministic `install.sh`.
