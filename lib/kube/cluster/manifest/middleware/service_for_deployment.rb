# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Generates a Service for every pod-bearing resource that has
        # containers with named ports.
        #
        # The generated Service uses +spec.selector.matchLabels+ from
        # the source resource and maps each named container port.
        #
        # Labels and namespace are copied from the source resource, so
        # subsequent middleware (Labels, Namespace, etc.) will also
        # apply to the generated Service.
        #
        #   stack do
        #     use Middleware::ServiceForDeployment
        #   end
        #
        class ServiceForDeployment < Middleware
          def call(resource)
            return resource unless pod_bearing?(resource)

            h = resource.to_h
            ports = extract_ports(h)
            return resource if ports.empty?

            match_labels = h.dig(:spec, :selector, :matchLabels)
            return resource unless match_labels && !match_labels.empty?

            service = Kube::Schema["Service"].new {
              metadata.name      = h.dig(:metadata, :name)
              metadata.namespace = h.dig(:metadata, :namespace) if h.dig(:metadata, :namespace)
              metadata.labels    = h.dig(:metadata, :labels) || {}

              spec.selector = match_labels
              spec.ports = ports.map { |p|
                {
                  name:       p[:name],
                  port:       p[:containerPort],
                  targetPort: p[:name],
                  protocol:   p.fetch(:protocol, "TCP"),
                }
              }
            }

            [resource, service]
          end

          private

            def extract_ports(hash)
              pod_spec = pod_template(hash)
              return [] unless pod_spec

              ports = []
              each_container(pod_spec) do |container|
                Array(container[:ports]).each do |port|
                  ports << port if port[:name]
                end
              end
              ports
            end
        end
      end
    end
  end
end
