# CmuxNestedTopology

Provider-neutral nested topology model for cmux (PR 1 of the native Herdr nested-topology plan).

This package owns pure domain types and reducers only:

- compound nested node IDs
- immutable topology snapshots
- workspace / tab / pane / agent node values
- topology events and a validating pure reducer
- capability sets and connection-state values
- in-memory association, parent-map, and title-lock values

It does **not** open sockets, touch the filesystem, or render UI. Those land in later PRs.

## Test

```bash
swift test --package-path Packages/macOS/CmuxNestedTopology
```

## Related

- manaflow-ai/cmux#8737
- Upstream PR plan PR 1: provider-neutral model and IDs
