## Agent skills

### Issue tracker

Issues are tracked in this repository's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

The default canonical triage labels are used. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository. See `docs/agents/domain.md`.

## Verification

After each code change run
these checks from the repository root:

- `dart analyze`
- `dcm analyze .`
- `dcm calculate-metrics` for the changed owners, starting with separate
  production, test, and tool scopes such as `lib/src/<owner>`,
  `test/<area>`, and `tool/<area>`.

Also run the focused tests that cover the changed behavior.

## DCM metrics exceptions

- Treat DCM metrics as review signals, not design targets. Do not split,
  wrap, or otherwise reshape cohesive code only to satisfy a metric threshold.
- When a metric violation is an intentional architecture or readability
  trade-off, suppress only the specific metric on the specific declaration that
  needs the exception. Use exact metric names such as
  `// ignore: halstead-volume, source-lines-of-code`; do not use broad
  `// ignore: metrics`, file-level metric suppression, or repository-level
  threshold/configuration changes to silence localized exceptions.
- Every metrics suppression must have a nearby plain-language comment that
  explains why keeping the code together is clearer or safer than reshaping it
  for the metric.
- If the same kind of metrics suppression becomes repeated across several
  files, stop treating it as a local exception. Revisit the owning abstraction,
  file boundary, or repository-level DCM configuration before adding more
  suppressions.
