# macOS M1 lifecycle prototype

This directory is an isolated, marker-only prototype for macOS 12+ launchd
lifecycle research. It does not create sudoers policy and does not modify the
installed `/usr/local/bin/agent-temporary`.

Two static root LaunchDaemons implement the lifecycle. The activation-triggered
`com.agent-temporary.m1.expire` job runs the expiry reaper, while
`com.agent-temporary.m1.boot` uses `RunAtLoad` for boot revocation. The reaper
owns a root-controlled state file and `test-authority` marker under
`/var/db/agent-temporary-m1`. `expires_at` is an absolute wall-clock deadline;
the reaper checks it directly after wake/restart. A non-persistent activation
records the boot identity from `sysctl kern.boottime` and revokes on a later
boot. Persistent mode preserves the original deadline.

The boot plist uses only long-standing launchd keys: `RunAtLoad`,
`KeepAlive/SuccessfulExit`, and `ThrottleInterval`; the expiry plist is
activation-triggered and deliberately has no `RunAtLoad`. Install/load is
performed with `launchctl bootstrap system <expiry-plist> <boot-plist>`;
status/recovery uses `print` and `kickstart`.
