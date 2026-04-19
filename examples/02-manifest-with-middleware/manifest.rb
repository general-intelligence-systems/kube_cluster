require "bundler/setup"
require "kube/cluster"

APP_NAME        = "my-app"
FULLNAME        = "my-app"
IMAGE           = "my-app:latest"
MATCH_LABELS    = { app: APP_NAME }
STANDARD_LABELS = { app: APP_NAME, version: "1.0" }
RESOURCES       = { requests: { cpu: "100m", memory: "128Mi" }, limits: { cpu: "500m", memory: "256Mi" } }

require_relative 'templates/config_map'
require_relative 'templates/deployment'
require_relative 'templates/ingress'
require_relative 'templates/service'
require_relative 'templates/horizontal_pod_autoscaler'

require_relative 'middleware/labels'
require_relative 'middleware/namespace'

namespace = APP_NAME

manifest = Kube::Cluster::Manifest.new(
  ConfigMap.new(namespace: namespace),
  Deployment.new(namespace: namespace),
  Ingress.new(namespace: namespace),
  Service.new(namespace: namespace),
  HorizontalPodAutoscaler.new(namespace: namespace),
)

stack = Kube::Cluster::Middleware::Stack.new do
  use Middleware::Namespace
  use Middleware::Labels
end

stack.call(manifest)

puts manifest.to_yaml
