# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-07-13

### Added
- `Standard::CloudNativePg::Cluster` — a thin CloudNativePG `Cluster` CR wrapper
  (sets `metadata.name`/`metadata.namespace`; the large, deployment-specific spec
  is supplied via the block).

## [1.1.0] - 2026-07-13

### Added
- `Standard::CDI::DataVolume` — a thin CDI `DataVolume` wrapper (was stubbed
  out), pinned to `cdi.kubevirt.io/v1beta1/DataVolume` in the resolve table.
- lefthook `pre-commit` hook that runs the full test suite (`bin/test`) before
  every commit; add `lefthook` as a development dependency.

## [1.0.1] - 2026-07-13

### Added
- `require "kube/cluster/standard"` — an aggregator that loads the entire
  Standard tree at once, for projects that use most of it. The tree remains
  opt-in (`require "kube/cluster"` alone does not load it), so resolve overrides
  still take effect. The core auto-require now also skips this aggregator file.

## [1.0.0] - 2026-07-13

### Added
- `Kube::Cluster.config` / `resolve` DSL backed by an internal resolve table
  that `Kube::Cluster.[]` consults first, so a bare kind can be pinned to an
  explicit `group/version/Kind` instead of whatever the schema registry lists
  first.
- Resolve-table pins for every bare kind referenced under
  `kube/cluster/standard` — Perses (`v1alpha2`), Gateway API (`v1`), built-in
  Kubernetes kinds, and the Metacontroller, CloudNativePG, External Secrets,
  KubeVirt, k3s HelmChart, and VictoriaMetrics CRDs.
- `config` warns when `Kube::Cluster::Standard` is already loaded, since those
  classes have already bound their (now stale) superclasses.
- Test guarding that every bare kind used in the standard tree is pinned in the
  resolve table.

### Changed
- **Breaking:** the `kube/cluster/standard` tree is no longer auto-required by
  `require "kube/cluster"`. Projects must require the specific standard classes
  they use, so resolve overrides can be configured beforehand.

### Fixed
- `Standard::Perses::Perses` and `Standard::Perses::PersesDatasource` now resolve
  to `perses.dev/v1alpha2` instead of the deprecated `v1alpha1` a bare-kind
  lookup defaulted to.

[1.0.0]: https://github.com/general-intelligence-systems/kube_cluster/releases/tag/v1.0.0
