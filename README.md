# agent-temporary

A small, cross-platform wrapper for granting a local automation agent temporary
passwordless `sudo` access.

## Install

Run as the user who should receive access:

```sh
sudo ./agent-temporary install
```

Installation copies the wrapper to `/usr/local/bin/agent-temporary`, records
the target user in `/etc/agent-temporary.conf`, backs up existing managed files,
and leaves temporary access **disabled**.

## Use

```sh
sudo agent-temporary on
sudo agent-temporary status
sudo agent-temporary off
```

`on` creates `/etc/sudoers.d/90-temporary-agent` with a full
`NOPASSWD: ALL` grant. Use it only on machines you control, and run `off` as
soon as the agent task is complete. The installer validates sudoers syntax with
`visudo` and detects the platform's root group (`wheel` on macOS, `root` on
most Linux systems).

## Supported systems

The script targets macOS and Linux systems with `sudo`, `visudo`, and a POSIX
shell. It does not configure SSH, Tailscale, or an agent runtime.
