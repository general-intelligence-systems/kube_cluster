# frozen_string_literal: true

module Kube
  module Cluster
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
        def call(manifest)
          generated = []

          manifest.resources.each do |resource|
            next unless resource.pod_bearing?

            h = resource.to_h
            ports = extract_ports(resource, h)
            next if ports.empty?

            match_labels = h.dig(:spec, :selector, :matchLabels)
            next unless match_labels && !match_labels.empty?

            generated << Kube::Cluster["Service"].new {
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
          end

          manifest.resources.concat(generated)
        end

        private

          def extract_ports(resource, hash)
            pod_spec = resource.pod_template(hash)
            return [] unless pod_spec

            ports = []
            resource.each_container(pod_spec) do |container|
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
