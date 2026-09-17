# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.8.0] - 2026-09-17

### Added
- `Standard::RbacRules` — the rules-shorthand builder behind
  `Standard::Role`, now a shared module. The spec grammar handles
  `"resource"`, `"resource/subresource"`, `"group/resource"` and
  `"group/resource/subresource"`: the first segment is an API group when
  `Kube::Schema.api_groups` knows it (`batch`, `apps`, `argoproj.io`, ...) or
  when it contains a dot (API groups are DNS subdomains, which covers CRD
  groups no schema has registered). Verbs are stringified, so symbols work.
- `Standard::ClusterRole` — the rules shorthand, cluster-wide.
- `Standard::ClusterRoleBinding` — wires a ClusterRole to a ServiceAccount,
  mirroring `Standard::RoleBinding`.
- `Middleware::SetNamespace` now fills blank ServiceAccount subject
  namespaces on ClusterRoleBinding as well as RoleBinding. ClusterRoleBinding
  is cluster-scoped, so there is no metadata.namespace to copy from — the
  middleware fills the subjects directly.
- `ClusterRole` and `ClusterRoleBinding` pinned in the resolve table.

### Changed
- Requires kube_schema `~> 1.11.0` for `Kube::Schema.api_groups`.

### Fixed
- The rules shorthand parsed `"pods/exec"` as `apiGroups: ["pods"],
  resources: ["exec"]` — a rule matching nothing. Core subresources now
  render as `apiGroups: [""], resources: ["pods/exec"]`.

## [1.7.0] - 2026-09-17

### Added
- `Standard::EnvProcessing` now maps `ESO::ExternalSecret::KeyRef` (the struct
  returned by `ExternalSecret#key`) to a `secretKeyRef` env var, mirroring the
  support `VolumeProcessing` has always had. Unlike `.template`, `.key`
  registers nothing on the ExternalSecret — it references a key the secret
  already materialises (declared via `keys:` at construction, or by a
  `.template` call elsewhere). This makes `Custom::PassboltSecret`-style
  secrets — whose template is fully built at construction — usable from env
  hashes, where previously the only option was a raw `valueFrom` hash or a
  whole-secret `envFrom`.

## [1.6.0] - 2026-08-03

### Added
- `Standard::JuiceFS::Sync` — a wrapper for the juicefs-operator's `Sync` CRD
  (pinned to `juicefs.io/v1`). `from`/`to` are the CRD's sink hashes, passed
  through as-is. Documents two operator behaviours worth knowing before use: the
  unquoted metadata-URL export that breaks `juicefsCE` sinks whose metaurl
  contains `&`, and the `ttlSecondsAfterFinished` deletion that makes a
  reconciler-managed Sync re-run forever.
- `Standard::JuiceFS::PersistentVolume` — a statically-provisioned JuiceFS PV,
  the only way to give a volume an exact, readable directory name (`subPath`)
  rather than the `pvc-<uuid>` a StorageClass would assign.
- `PersistentVolume` pinned to `v1/PersistentVolume` in the resolve table.

### Changed
- Requires kube_schema `~> 1.10.0`, which ships the `juicefs.io/v1` schemas.
  These wrappers previously needed a local CRD-registration shim that downloaded
  `dist/crd.yaml` at load time; that is no longer necessary.

## [1.4.0] - 2026-07-13

### Added
- `Standard::VictoriaMetrics::VMRule` — a wrapper for the VictoriaMetrics
  operator's `VMRule` CRD (pinned to `operator.victoriametrics.com/v1beta1`).
  Rules are built from `VMRule::Group` objects, each exposing `rule`/`alert`
  helpers that construct `Rule`/`Alert` leaves; the rule expression is the
  return value of a block, so multi-line PromQL reads as a heredoc.
- `Standard::VictoriaMetrics::VMAlert` — a wrapper for the VictoriaMetrics
  operator's `VMAlert` CRD (pinned to `operator.victoriametrics.com/v1beta1`).
  Wires `datasource`/`remoteWrite`/`remoteRead` and defaults `selectAllByDefault`
  to true so it evaluates every `VMRule`; `notifier_url` is optional (recording
  rules need no notifier).

## [1.3.1] - 2026-07-13

### Changed
- `Standard::CloudNativePg::Cluster` is now the bare named `Cluster` CR subclass
  (resolved to `postgresql.cnpg.io/v1/Cluster`); the whole spec is supplied via
  the block.

### Removed
- `Standard::CloudNativePg::PostgresCluster` (shipped in 1.3.0) — it baked in a
  specific deployment's config, which belongs at the call site, not the library.

## [1.3.0] - 2026-07-13

### Added
- `Standard::CloudNativePg::PostgresCluster` — the standard single-node
  PostgreSQL cluster (custom image, HA replication slots, logical WAL,
  barman-cloud WAL archiving) preconfigured; deployment-specific spec (managed
  roles, etc.) via the block.

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
