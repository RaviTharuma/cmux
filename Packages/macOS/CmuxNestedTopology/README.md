# CmuxNestedTopology

Provider-neutral nested topology model, read-only Herdr socket adapter, secure
attachment lifecycle, and **read projection** for cmux (PR 1–4 of the native
Herdr nested-topology plan).

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
- **PR4 read projection**
  - ``NestedTopologyTwoPassRenderer`` / ``NestedTopologyReadService``
  - public read nodes + ``nested.topology.list`` JSON payload helpers
  - immutable ``NestedSidebarSubtreeSnapshot`` for sidebar mounting
  - cmux→client capability token ``nested_topology.read.v1``

It does **not** mutate cmux `Workspace` / Bonsplit state, forward focus (PR 5),
or persist restore descriptors (PR 6). Herdr descendants remain virtual under one
host surface; they are never mirrored into Ghostty/Bonsplit PTYs.

## Read API (PR 4)

### Two-pass render

1. **Parent map** — ``NestedParentMap.replace(with:)`` from the snapshot (never
   re-inferred from titles each tick).
2. **Title locks** — ``NestedAssociationStore.proposeTitle`` suppresses overwrite
   when locked; the renderer diffs against last published labels so provider
   echoes do not thrash UI/socket consumers.

### Control socket (app-wired)

- Semantic capability: `nested_topology.read.v1` (additive `capabilities` array
  on `system.capabilities`)
- Method: `nested.topology.list` (optional `host_surface_id` / `host_workspace_id`)
- Default `system.tree` is unchanged (byte-compatible). Prefer
  `nested.topology.list` over extending the default tree; package helper
  ``NestedTopologyControlSocketPayload/foundationNestedTreeObject(attachments:)``
  exists if `include_nested` is wired later.
- Gated by beta flag `nestedTopology.beta.enabled` (same pattern as remote tmux)

### Sidebar

``NestedSidebarSubtreeSnapshot`` is an immutable value for expandable rows under
the host workspace/surface. Mount via app ``NestedSidebarSubtreeView``; rows must
not hold the attachment coordinator or other observable stores.

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

Adapter, attachment, and read-projection tests use temporary Unix-socket fakes
(or stubs) and do not require a live Herdr.

## Related

- manaflow-ai/cmux#8737
- cmux-herdr tracking: https://github.com/RaviTharuma/cmux-herdr/issues/11
- Upstream PR plan PR 1–3: model, Herdr adapter, attachment lifecycle
- Upstream PR plan PR 4: read UI + control-socket parity
