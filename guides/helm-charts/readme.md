# Helm Charts

This guide covers loading Helm charts as kube_cluster manifests.

## Loading a Chart

```ruby
manifest = Kube::Helm::Repo
  .new("bitnami", url: "https://charts.bitnami.com/bitnami")
  .fetch("nginx", version: "18.1.0")
  .apply_values("replicaCount" => 3)

puts manifest.to_yaml
```

Helm charts are fetched, templated, and returned as standard kube_cluster manifests. You can then apply middleware, modify resources, or deploy them.
