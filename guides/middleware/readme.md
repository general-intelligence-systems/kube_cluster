# Middleware

This guide covers the middleware stack that transforms a single Deployment declaration into a fully-configured stack.

## The Middleware Stack

```ruby
manifest = Kube::Cluster::Manifest.new(
  Kube::Cluster["Deployment"].new {
    metadata.name = "web"
    metadata.labels = {
      "app.kubernetes.io/expose": "app.example.com",
      "app.kubernetes.io/autoscale": "2-10",
      "app.kubernetes.io/size": "small"
    }
    spec.selector.matchLabels = { app: "web" }
    spec.template.spec.containers = [
      { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] }
    ]
  }
)

Kube::Cluster::Middleware::Stack.new {
  use Middleware::ServiceForDeployment
  use Middleware::IngressForService
  use Middleware::HPAForDeployment
  use Middleware::SetNamespace, "production"
  use Middleware::Labels, managed_by: "kube_cluster"
  use Middleware::ResourcePreset
  use Middleware::SecurityContext
  use Middleware::PodAntiAffinity
}.call(manifest)

puts manifest.to_yaml  # => Deployment, Service, Ingress, HPA -- all configured
```

## Available Middleware

| Middleware | Effect |
|---|---|
| `Namespace` | Sets `metadata.namespace` on all resources |
| `Labels` | Merges standard Kubernetes labels |
| `Annotations` | Merges annotations |
| `ResourcePreset` | Injects CPU/memory from `app.kubernetes.io/size` (nano to 2xlarge) |
| `SecurityContext` | Injects restricted/baseline security contexts |
| `PodAntiAffinity` | Spreads pods across nodes |
| `ServiceForDeployment` | Generates Service from named container ports |
| `IngressForService` | Generates Ingress from `app.kubernetes.io/expose` label |
| `HPAForDeployment` | Generates HPA from `app.kubernetes.io/autoscale` label |
