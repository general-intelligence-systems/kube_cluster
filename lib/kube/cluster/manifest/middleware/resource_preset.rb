# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Reads the +app.kubernetes.io/size+ label from pod-bearing
        # resources and injects CPU/memory requests and limits into
        # every container.
        #
        # The label on the resource is the input:
        #
        #   Kube::Schema["Deployment"].new {
        #     metadata.labels = { "app.kubernetes.io/size": "small" }
        #     ...
        #   }
        #
        # Register in the stack — no arguments needed:
        #
        #   stack do
        #     use Middleware::ResourcePreset
        #   end
        #
        # Available sizes: nano, micro, small, medium, large, xlarge, 2xlarge.
        # Limits are ~1.5x requests (following Bitnami conventions).
        #
        class ResourcePreset < Middleware
          LABEL = :"app.kubernetes.io/size"

          PRESETS = {
            "nano"    => { requests: { cpu: "100m",  memory: "128Mi"  }, limits: { cpu: "150m",  memory: "192Mi"  } },
            "micro"   => { requests: { cpu: "250m",  memory: "256Mi"  }, limits: { cpu: "375m",  memory: "384Mi"  } },
            "small"   => { requests: { cpu: "500m",  memory: "512Mi"  }, limits: { cpu: "750m",  memory: "768Mi"  } },
            "medium"  => { requests: { cpu: "500m",  memory: "1024Mi" }, limits: { cpu: "750m",  memory: "1536Mi" } },
            "large"   => { requests: { cpu: "1",     memory: "2048Mi" }, limits: { cpu: "1.5",   memory: "3072Mi" } },
            "xlarge"  => { requests: { cpu: "1",     memory: "3072Mi" }, limits: { cpu: "3",     memory: "6144Mi" } },
            "2xlarge" => { requests: { cpu: "1",     memory: "3072Mi" }, limits: { cpu: "6",     memory: "12288Mi" } },
          }.freeze

          def call(resource)
            size = label(resource, LABEL)
            return resource unless size
            return resource unless pod_bearing?(resource)

            preset = PRESETS.fetch(size.to_s) do
              raise ArgumentError, "Unknown size preset: #{size.inspect}. " \
                "Valid sizes: #{PRESETS.keys.join(', ')}"
            end

            h = resource.to_h
            pod_spec = pod_template(h)
            return resource unless pod_spec

            each_container(pod_spec) do |container|
              container[:resources] = deep_merge(preset, container[:resources] || {})
            end

            rebuild(resource, h)
          end
        end
      end
    end
  end
end
