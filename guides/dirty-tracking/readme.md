# Dirty Tracking

This guide covers dirty tracking and patching for resources connected to a live cluster.

## Connecting to a Cluster

```ruby
cluster = Kube::Cluster.connect(kubeconfig: "~/.kube/config")
```

## Creating and Patching Resources

```ruby
config = Kube::Cluster["ConfigMap"].new(cluster:) {
  metadata.name = "app-config"
  self.data = { version: "1" }
}

config.apply           # creates on cluster
config.data.version = "2"
config.changed?        # => true
config.patch           # sends only { data: { version: "2" } }
```

Changes are tracked automatically. When you call `patch`, only the modified fields are sent to the cluster.
