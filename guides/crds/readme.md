# Custom Resource Definitions

This guide covers registering CRDs from Helm charts as first-class resources.

## Registering CRDs

```ruby
chart = Kube::Helm::Repo.new("jetstack", url: "https://charts.jetstack.io")
  .fetch("cert-manager", version: "1.17.2")

chart.crds.each { |crd|
  s = crd.to_json_schema
  Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
}
```

## Using Registered CRDs

Once registered, CRDs work like any built-in resource:

```ruby
issuer = Kube::Cluster["ClusterIssuer"].new {
  metadata.name = "letsencrypt"
  spec.acme.server = "https://acme-v02.api.letsencrypt.org/directory"
}
```
