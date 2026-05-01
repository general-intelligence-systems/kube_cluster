# Getting Started

This guide walks you through installing kube_cluster and defining your first Kubernetes resource in Ruby.

## Install

```ruby
gem "kube_cluster", "~> 0.3"
```

## Define a Resource

```ruby
pod = Kube::Cluster["Pod"].new {
  metadata.name = "redis"
  spec.containers = [{ name: "redis", image: "redis:8" }]
}

puts pod.to_yaml
```

## Subclass for Reuse

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
