require "bundler/setup"
require "kube/cluster"

require_relative "pod_with_ingress"

manifest = Kube::Cluster::Manifest.new(
  PodWithIngress.new(
    name: "my-app",
    image: "registry:5000/myapp:v1",
    port: 3000,
    host: "localhost",
  ),
)

puts manifest.to_yaml
