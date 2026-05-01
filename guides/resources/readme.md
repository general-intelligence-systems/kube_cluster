# Resources

This guide covers defining and working with Kubernetes resources as Ruby objects.

## Defining Resources

Every Kubernetes kind is accessible by name:

```ruby
pod = Kube::Cluster["Pod"].new {
  metadata.name = "redis"
  spec.containers = [{ name: "redis", image: "redis:8" }]
}
```

## Subclassing

Create reusable resource templates by subclassing:

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

## Manifests

Group resources into multi-document YAML using manifests:

```ruby
manifest = Kube::Cluster::Manifest.new(
  Kube::Cluster["Deployment"].new {
    metadata.name = "web"
    spec.selector.matchLabels = { app: "web" }
    spec.template.spec.containers = [
      { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] }
    ]
  }
)

puts manifest.to_yaml
```
