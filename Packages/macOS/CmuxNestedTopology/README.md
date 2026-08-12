# CmuxNestedTopology

Provider-neutral nested topology model and read-only Herdr socket adapter for cmux
(PR 1 + PR 2 of the native Herdr nested-topology plan).

## Scope

This package owns:

- compound nested node IDs and immutable topology snapshots
- workspace / tab / pane / agent node values
- topology events and a validating pure reducer
- capability sets and connection-state values
- in-memory association, parent-map, and title-lock values
- provider-neutral ``NestedTopologyProviderClient``
- ``HerdrNestedTopologyClient`` (newline-delimited JSON Unix socket; no `herdr` CLI)

It does **not** render UI, own attachment lifecycle/security checks (PR 3), or mutate
cmux `Workspace` / Bonsplit state. Herdr descendants remain virtual under one host
surface; they are never mirrored into Ghostty/Bonsplit PTYs.

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

Adapter tests use a temporary Unix-socket fake server and do not require a live Herdr.

## Related

- manaflow-ai/cmux#8737
- Upstream PR plan PR 1: provider-neutral model and IDs
- Upstream PR plan PR 2: read-only Herdr socket adapter
