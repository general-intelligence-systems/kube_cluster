# kube_cluster

Ruby-native Kubernetes. Define, transform, and deploy cluster resources with pure Ruby.

## Install

```ruby
gem "kube_cluster", "~> 0.3"
```

## Examples

### Define a resource

```ruby
pod = Kube::Cluster["Pod"].new {
  metadata.name = "redis"
  spec.containers = [{ name: "redis", image: "redis:8" }]
}

puts pod.to_yaml
```

### Subclass for reuse

```ruby
class RedisPod < Kube::Cluster["Pod"]
  def initialize(&block)
    super {
      metadata.name = "redis"
      spec.containers = [{ name: "redis", image: "redis:8", ports: [{ containerPort: 6379 }] }]
    }
    instance_exec(&block) if block_given?
  end
end

puts RedisPod.new { metadata.namespace = "production" }.to_yaml
```

### Manifest + middleware

One Deployment declaration becomes a fully-configured stack:

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
  use Middleware::Namespace, "production"
  use Middleware::Labels, managed_by: "kube_cluster"
  use Middleware::ResourcePreset
  use Middleware::SecurityContext
  use Middleware::PodAntiAffinity
}.call(manifest)

puts manifest.to_yaml  # => Deployment, Service, Ingress, HPA — all configured
```

### Dirty tracking + patching

```ruby
cluster = Kube::Cluster.connect(kubeconfig: "~/.kube/config")

config = Kube::Cluster["ConfigMap"].new(cluster:) {
  metadata.name = "app-config"
  self.data = { version: "1" }
}

config.apply           # creates on cluster
config.data.version = "2"
config.changed?        # => true
config.patch           # sends only { data: { version: "2" } }
```

### Helm charts as manifests

```ruby
manifest = Kube::Helm::Repo
  .new("bitnami", url: "https://charts.bitnami.com/bitnami")
  .fetch("nginx", version: "18.1.0")
  .apply_values("replicaCount" => 3)

puts manifest.to_yaml
```

### Register CRDs as first-class resources

```ruby
chart = Kube::Helm::Repo.new("jetstack", url: "https://charts.jetstack.io")
  .fetch("cert-manager", version: "1.17.2")

chart.crds.each { |crd|
  s = crd.to_json_schema
  Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
}

issuer = Kube::Cluster["ClusterIssuer"].new {
  metadata.name = "letsencrypt"
  spec.acme.server = "https://acme-v02.api.letsencrypt.org/directory"
}
```

## Middleware

| Middleware | Effect |
|---|---|
| `Namespace` | Sets `metadata.namespace` on all resources |
| `Labels` | Merges standard Kubernetes labels |
| `Annotations` | Merges annotations |
| `ResourcePreset` | Injects CPU/memory from `app.kubernetes.io/size` (nano → 2xlarge) |
| `SecurityContext` | Injects restricted/baseline security contexts |
| `PodAntiAffinity` | Spreads pods across nodes |
| `ServiceForDeployment` | Generates Service from named container ports |
| `IngressForService` | Generates Ingress from `app.kubernetes.io/expose` label |
| `HPAForDeployment` | Generates HPA from `app.kubernetes.io/autoscale` label |

## More examples

See the [`examples/`](examples/) directory for complete runnable projects.

## License

Apache-2.0
