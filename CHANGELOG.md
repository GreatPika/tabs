# Changelog

## 5.2.0

- Add opt-in `unselectedTabColor` surfaces for unselected labels on every tab
  edge, using the same joined contour and radius settings as the active tab.
- Add `unselectedTabGap`, with transparent gaps between unselected tab labels.
- Add opt-in `unselectedTabBorder` for separating inactive tab labels from
  their background.
- Keep a tab's unselected color throughout its selection transition and avoid
  revealing an inactive surface behind the active tab while labels collapse.
- Update the example to demonstrate the inactive-label surface styling.

## 5.1.0

- Add `border` for a uniform outline around the active tab and its content.
- Add `TabsActionButton.widget` for action icons rendered by arbitrary widgets.
- Keep `borderRadius` and `tabBorderRadius` corners in physical screen
  coordinates on every tab edge.
- Apply `tabButtonGap` to the outer edges of tab-strip action buttons.

## 5.0.0

- Narrow the root package export to the supported widgets, tab edge, and
  tab-strip action-button types while keeping the import path as
  `package:tabs/tabs.dart`.
- Remove `TabsController`; use Flutter's `TabController` with
  `Tabs(controller: ...)`.
- Remove deprecated `Tabs` constructor parameters `radius`, `isStringTabs`,
  `tabDuration`, `tabCurve`, `tabStart`, and `tabEnd` in favor of
  `borderRadius`, explicit tab widgets, `duration`, `curve`, `tabsStart`, and
  `tabsEnd`.
- Stop exposing render internals from the package root.
- Replace the low-level wrapper semantics override with `semanticsLabel`,
  `semanticsHint`, and `semanticsValueBuilder`; the value builder receives
  zero-based `TabController` indices and null parameters keep the default
  wrapper semantics text.
- Add per-tab semantics so each tab reports button, selected, enabled, and tap
  behavior while preserving caller-provided tab labels and custom child
  semantics.
- Add `tabLeadingButtons` and `tabTrailingButtons` for library-generated
  Material tab-strip buttons separated from tab labels by `tabButtonGap` and
  shaped to the same radius as tab labels.
- Add `TabsActionButtonVariant` so tab-strip buttons can use standard, filled,
  filled tonal, or outlined Material button variants.
- Add `TabsActionButton.widget` for icon packages that render icons as widgets,
  including `hugeicons`.
- Change package-managed `children` mode so transitions switch only the active
  child; inactive child-state retention is caller-owned through `child` with an
  `IndexedStack`, `PageView`, or equivalent container.
- Stabilize rebuild-time text style, text direction, color-list updates,
  active-child switching, animation invalidation, and render path/clip cache
  behavior with focused widget and public API coverage.
- Raise the package floor to Dart `^3.8.0` and Flutter `>=3.32.0`, and update
  `flutter_lints` to `^6.0.0`.
- Retain the original MIT copyright notice and add attribution for fork
  contributions.
