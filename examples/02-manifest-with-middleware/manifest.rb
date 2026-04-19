require_relative 'templates/config_map'
require_relative 'templates/deployment'
require_relative 'templates/ingress'
require_relative 'templates/service'
require_relative 'templates/horizontal_pod_autoscaler'

require_relative 'middlware/labels'
require_relative 'middlware/namespace'

class MyApp < Kube::Schema::Manifest
  stack do
    use Middleware::Namespace
    use Middleware::Labels
  end
end

puts MyApp.new(
  Templates::ConfigMap.new {
    # no overrides today
  },

  Templates::Deployment.new {
    # no overrides today
  },

  Templates::Ingress.new {
    # no overrides today
  },

  Templates::Service.new {
    # no overrides today
  },

  Templates::HorizontalPodScaler.new {
    # no overrides today
  },
).to_yaml
