# agent-temporary

Give a user or local automation root access for a limited time, then take it away automatically.

agent-temporary provides explicitly bounded passwordless sudo access on Linux and macOS. An administrator creates the grant, it has a fixed deadline, and local expiry/reboot handling revokes it automatically.

## Why

Local automation or an interactive workflow may temporarily need root. A permanent passwordless sudo grant leaves permanent authority behind. agent-temporary makes that authority time-bounded:

```text
administrator approval
          ↓
temporary root access
          ↓
      fixed expiry
          ↓
automatic revocation
```

Revocation is local; no remote controller is required.

## Install

Preferred distribution with npm:

```sh
npm install -g agent-temporary && agent-temporary-setup install
```

Run this as the normal user. The first operation installs or updates the unprivileged npm distribution package; only if it succeeds does `agent-temporary-setup install` verify that packaged release and request administrator privileges for the system installation. The same command is used for a first installation and future updates, and leaves temporary access inactive. Running only `npm install -g agent-temporary` does not update an existing system installation. A newer installed system version is not silently downgraded.

To remove the system installation:

```sh
agent-temporary-setup uninstall
```

`npm uninstall -g agent-temporary` removes only the npm package; it does not remove the system installation.

Users without npm may use the shell bootstrap:

```sh
curl -fsSL https://raw.githubusercontent.com/synrest/agent-temporary/main/bootstrap/install.sh | sh
```

Inspect it first when preferred:

```sh
curl -fsSL https://raw.githubusercontent.com/synrest/agent-temporary/main/bootstrap/install.sh -o agent-temporary-install.sh
sh agent-temporary-install.sh
```

The bootstrap resolves a concrete release version, downloads its exact ZIP and checksum, verifies the ZIP before requesting administrator privileges, and delegates system changes to the canonical installer. It does not activate temporary access.

For manual installation, download a release archive, inspect it, then run:

```sh
sudo ./install.sh --user <target-user>
```

Installation does not enable temporary access. After installation, use the commands below.

## Usage

```sh
agent-temporary status
sudo agent-temporary on --ttl 30m
sudo agent-temporary on --ttl 2h --persist-reboot
sudo agent-temporary off
agent-temporary version
agent-temporary --help
```

The default TTL is 5 minutes. The allowed range is 5 minutes through 8 hours. Use a positive integer followed by `m` or `h`, such as `5m`, `30m`, `1h`, or `8h`.

Without `--persist-reboot`, reboot revokes the temporary access. On macOS, `--persist-reboot` preserves the same grant across reboot until its original expiry; it does not create a new TTL.

`status` uses stable key/value output for machine-readable use. On macOS, a protected active state requires `sudo agent-temporary status`; inactive status can be checked without privilege.

## Security model

While active, the configured user has unrestricted passwordless sudo (`NOPASSWD: ALL`) access. agent-temporary does not sandbox or limit what that root access can do; its safety property is the deliberate time boundary.

The grant has a fixed absolute expiry. A second activation while access is active does not renew or extend it, and cannot change its reboot-persistence setting. Use `off` first.

Authority is proved by exact non-interactive sudo execution, not by trusting `sudo -l` or policy listing alone. Revocation is local and fail-closed where validation or transaction steps fail. The implementation does not use SSH keys or `authorized_keys`, and does not require Netbot or a remote controller.

## Platform

Supported platforms are Linux with an actually active systemd or OpenRC runtime and sudo/visudo, and macOS with launchd and sudo/visudo. Linux service-manager detection requires an active runtime; the presence of binaries alone is insufficient.

Unsupported or ambiguous platforms fail closed and are not given a synthetic service configuration.

## Release

Build the release artifacts with:

```sh
./release.sh
```

The release contains the executable, systemd/OpenRC/launchd service definitions, `VERSION`, `SHA256SUMS`, and the canonical `install.sh`. It also creates a versioned ZIP and SHA-256 sidecar. The archive contains no Git metadata, runtime state, logs, or private material.

---

Never assume. Verify.
