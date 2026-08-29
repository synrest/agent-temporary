# macOS M1 lifecycle prototype

This directory is an isolated, marker-only prototype for macOS 12+ launchd
lifecycle research. It does not create sudoers policy and does not modify the
installed `/usr/local/bin/agent-temporary`.

The static root LaunchDaemon is `com.agent-temporary.m1`. Its reaper owns a
root-controlled state file and `test-authority` marker under
`/var/db/agent-temporary-m1`. `expires_at` is an absolute wall-clock deadline;
the reaper checks it directly after wake/restart. A non-persistent activation
records the boot identity from `sysctl kern.boottime` and revokes on a later
boot. Persistent mode preserves the original deadline.

The plist uses only long-standing launchd keys: `RunAtLoad`,
`KeepAlive/SuccessfulExit`, and `ThrottleInterval`. Install/load is performed
with `launchctl bootstrap system <plist>`; status/recovery uses `print` and
`kickstart`.
