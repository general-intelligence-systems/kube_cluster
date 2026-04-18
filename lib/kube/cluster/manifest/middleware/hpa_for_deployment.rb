# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Generates a HorizontalPodAutoscaler for every pod-bearing
        # resource that carries the +app.kubernetes.io/autoscale+ label.
        #
        # The label value encodes the min and max replicas as "min-max":
        #
        #   metadata.labels = { "app.kubernetes.io/autoscale": "1-5" }
        #
        # Options:
        #   cpu:    — target CPU utilization percentage (default: 75)
        #   memory: — target memory utilization percentage (default: 80)
        #
        #   stack do
        #     use Middleware::HPAForDeployment
        #     use Middleware::HPAForDeployment, cpu: 60, memory: 70
        #   end
        #
        class HPAForDeployment < Middleware
          LABEL = :"app.kubernetes.io/autoscale"

          def initialize(cpu: 75, memory: 80)
            @cpu = cpu
            @memory = memory
          end

          def call(resource)
            return resource unless pod_bearing?(resource)

            value = label(resource, LABEL)
            return resource unless value

            min, max = parse_range(value)

            h = resource.to_h
            name      = h.dig(:metadata, :name)
            namespace = h.dig(:metadata, :namespace)
            labels    = h.dig(:metadata, :labels) || {}
            api_version = h[:apiVersion] || "apps/v1"
            resource_kind = kind(resource)

            # Capture ivars as locals — the block runs via instance_exec
            # on a BlackHoleStruct, so @ivars would resolve on the BHS.
            cpu_target    = @cpu
            memory_target = @memory

            hpa = Kube::Schema["HorizontalPodAutoscaler"].new {
              metadata.name      = name
              metadata.namespace = namespace if namespace
              metadata.labels    = labels.reject { |k, _| k == LABEL }

              spec.scaleTargetRef = {
                apiVersion: api_version,
                kind:       resource_kind,
                name:       name,
              }
              spec.minReplicas = min
              spec.maxReplicas = max
              spec.metrics = [
                {
                  type: "Resource",
                  resource: {
                    name: "cpu",
                    target: { type: "Utilization", averageUtilization: cpu_target },
                  },
                },
                {
                  type: "Resource",
                  resource: {
                    name: "memory",
                    target: { type: "Utilization", averageUtilization: memory_target },
                  },
                },
              ]
            }

            [resource, hpa]
          end

          private

            def parse_range(value)
              parts = value.to_s.split("-", 2)

              unless parts.length == 2
                raise ArgumentError,
                  "Invalid autoscale label: #{value.inspect}. Expected format: \"min-max\" (e.g. \"1-5\")"
              end

              min = Integer(parts[0])
              max = Integer(parts[1])

              unless min > 0 && max >= min
                raise ArgumentError,
                  "Invalid autoscale range: min=#{min}, max=#{max}. " \
                  "min must be > 0 and max must be >= min."
              end

              [min, max]
            end
        end
      end
    end
  end
end
