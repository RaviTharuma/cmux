# CmuxNestedTopology

Provider-neutral nested topology model, read-only Herdr socket adapter, and
secure attachment lifecycle for cmux (PR 1–3 of the native Herdr nested-topology
plan).

## Scope

This package owns:

- compound nested node IDs and immutable topology snapshots
- workspace / tab / pane / agent node values
- topology events and a validating pure reducer
- capability sets and connection-state values
- in-memory association, parent-map, and title-lock values
- provider-neutral ``NestedTopologyProviderClient``
- ``HerdrNestedTopologyClient`` (newline-delimited JSON Unix socket; no `herdr` CLI)
- ``NestedTopologyAttachmentCoordinator`` — opt-in attachment lifecycle, endpoint
  security validation, host move/close hooks, and plugin single-writer handoff

It does **not** render UI, wire control-socket nested tree APIs (PR 4), or mutate
cmux `Workspace` / Bonsplit state. Herdr descendants remain virtual under one host
surface; they are never mirrored into Ghostty/Bonsplit PTYs.

## Attachment lifecycle (PR 3)

``NestedTopologyAttachmentCoordinator`` is intended for app/window scope:

- Initial attach requires explicit ``NestedAttachmentAuthorization``
  (`.userConfirmed` or `.authenticatedControlSocket`). Environment/OSC may
  ``recordProposal`` only — proposals never authorize alone.
- Endpoint checks: absolute local Unix socket, `lstat` (final component must not
  be a symlink), current UID ownership, restrictive mode (`0600`), and
  device/inode identity recheck around connect.
- Host surface **move** preserves the attachment; **close** / teardown detaches
  without `server.stop` or child closes.
- When state becomes ``live``, a plugin single-writer handoff lock/env signal is
  acquired (``NestedPluginWriterHandoff``). Leaving `live` releases it so plugin
  fallback may resume.
- Default telemetry never includes socket paths or provider payloads.

## Herdr protocol 17 notes

Adaptation lives in ``HerdrProtocol17Compatibility``. Unknown JSON fields are
tolerated; missing required fields are errors.

**Instance identity gap:** protocol 17 `ping` does not return a durable
server-lifetime `instance_id`. Until Herdr advertises one, the client mints a fresh
``NestedProviderInstanceID`` per successful connection and invalidates association
entries from prior generations on reconnect/resnapshot.

## Test

```bash
swift test --package-path Packages/macOS/CmuxNestedTopology
```

Adapter and attachment tests use a temporary Unix-socket fake server (or stubs)
and do not require a live Herdr.

## Related

- manaflow-ai/cmux#8737
- cmux-herdr tracking: https://github.com/RaviTharuma/cmux-herdr/issues/11
- Upstream PR plan PR 1: provider-neutral model and IDs
- Upstream PR plan PR 2: read-only Herdr socket adapter
- Upstream PR plan PR 3: secure attachment lifecycle
