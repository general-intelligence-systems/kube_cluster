# 05 — Helm Chart to Manifest

Fetches a Helm chart from a repository, renders it with custom values, and converts the output into typed Ruby `Kube::Schema::Resource` objects.

No running cluster is required — `helm template` renders everything locally.

## Prerequisites

- `helm` CLI installed
- `bundle install`

## Run

```
bin/dev
```

## What it does

`manifest.rb` demonstrates the full Helm → Ruby pipeline:

1. **Registers a Helm repo** — `Kube::Helm::Repo.new("bitnami", url: "...")`
2. **Gets a chart reference** — `repo.chart("nginx", version: "18.1.0")`
3. **Inspects default values** — `chart.show_values` returns a Ruby hash
4. **Renders with custom values** — `chart.template(release:, namespace:, values:)` returns a `Kube::Schema::Manifest`
5. **Iterates typed resources** — each item is a real `Resource` with `.kind`, `.metadata.name`, `.spec.replicas`, etc.
6. **Applies middleware** — the rendered resources pass through the same middleware stack as hand-written resources
7. **Writes YAML** — `manifest.write("manifest.yaml")`

## OCI Registry Example

For OCI-based registries, no `repo.add` is needed:

```ruby
repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
chart = repo.chart("my-app", version: "1.0.0")
manifest = chart.template(release: "my-app", namespace: "production")
```

## Files

| File | Purpose |
|---|---|
| `manifest.rb` | Fetches chart, renders with values, outputs YAML |
