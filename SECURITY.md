# Security Policy

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue for
anything exploitable.

- Preferred: GitHub's **private vulnerability reporting** (the "Report a
  vulnerability" button under the repository's *Security* tab).
- Or email **julian@gaind.ai** with the details and steps to reproduce.

You'll get an acknowledgement within a few days. Since this is a small,
volunteer-maintained tool, please allow reasonable time for a fix before public
disclosure. There is no bug-bounty program.

## What this tool touches (threat model)

This is an unsandboxed background app plus a sandboxed widget. It reads usage
data Claude Code already stores on your Mac and shows it on your desktop. The
design goal is that you can run it without trusting the author with anything
sensitive.

**Credentials**
- The Claude Code OAuth token is read from the macOS keychain **at runtime**,
  held **in memory only**, and used solely as the `Authorization` header for a
  single request to `api.anthropic.com`. It is **never written to disk, never
  logged, and never placed in the snapshot file**.
- A redirect guard ensures the token is only ever sent to `api.anthropic.com` —
  it is not forwarded if the endpoint were to redirect elsewhere.
- The keychain access prompts you once ("Always Allow"); the grant is bound to
  the app's signing identity (see *Build & signing* below).

**Network**
- Exactly **one** outbound destination: `api.anthropic.com` (HTTPS, ATS
  enforced, an ephemeral URL session with no cookie or cache persistence).
- No telemetry, no analytics, no third-party servers, no auto-update channel.

**Filesystem**
- `~/.claude` (your Claude Code session logs) is **read-only, never written**.
- The app writes one file it owns: an aggregate snapshot at
  `~/Library/Application Support/ClaudeUsage/snapshot.json` (mode `0600`),
  containing **numbers only** — token counts, percentages, session counts —
  never prompts, transcripts, file contents, or tokens.
- The **widget** is sandboxed with a read-only exception scoped to that single
  directory. It cannot read `~/.claude`, the keychain, or anything else.

**Build & signing**
- Distributed as **source only**; you build it yourself. No prebuilt binaries.
- Zero third-party dependencies.
- Hardened Runtime is enabled and the debug `get-task-allow` entitlement is
  disabled, so the process that handles the token cannot be trivially attached
  to or injected into.
- `install.sh` creates a per-machine **self-signed** code-signing certificate
  (`Claude Usage Local Signing`) and signs with it. The private key never
  leaves your Mac and is never committed.

## Known, deliberate trade-offs

These are documented design choices, not undiscovered bugs:

- **The main background app is not sandboxed.** It needs read access to
  `~/.claude` and the keychain item, which the App Sandbox would block.
  Sandboxing it with scoped exceptions is on the roadmap. The widget *is*
  sandboxed.
- **It calls an undocumented Anthropic endpoint** (`/api/oauth/usage`, the same
  one `/usage` uses) with your own token and a `claude-code` user agent. This is
  not affiliated with or supported by Anthropic; see the Disclaimer in the
  [README](README.md). It only ever reads usage status — it never modifies your
  account.

## Out of scope

The following are not considered vulnerabilities in this project:

- The undocumented-endpoint usage and `claude-code` user agent (intentional and
  disclosed).
- The main app being unsandboxed (documented above).
- Issues that require an attacker who already has local access to your user
  account (at that point your keychain and `~/.claude` are already exposed
  regardless of this app).
- The self-signed certificate not being trusted by Gatekeeper (expected for a
  locally built, ad-hoc-distributed app).
