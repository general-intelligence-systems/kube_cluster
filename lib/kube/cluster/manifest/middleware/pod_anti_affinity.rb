# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Injects soft pod anti-affinity on pod-bearing resources so
        # that pods prefer to spread across nodes.
        #
        # The anti-affinity uses the resource's own +matchLabels+ from
        # +spec.selector.matchLabels+ as the label selector, and
        # +kubernetes.io/hostname+ as the topology key.
        #
        # Resources that already have +spec.template.spec.affinity+
        # set are left untouched.
        #
        #   stack do
        #     use Middleware::PodAntiAffinity
        #     use Middleware::PodAntiAffinity, topology_key: "topology.kubernetes.io/zone"
        #   end
        #
        class PodAntiAffinity < Middleware
          def initialize(topology_key: "kubernetes.io/hostname", weight: 1)
            @topology_key = topology_key
            @weight = weight
          end

          def call(resource)
            return resource unless pod_bearing?(resource)

            h = resource.to_h
            pod_spec = pod_template(h)
            return resource unless pod_spec

            # Don't overwrite existing affinity configuration.
            return resource if pod_spec[:affinity]

            match_labels = h.dig(:spec, :selector, :matchLabels)
            return resource unless match_labels && !match_labels.empty?

            pod_spec[:affinity] = {
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [
                  {
                    weight: @weight,
                    podAffinityTerm: {
                      labelSelector: { matchLabels: match_labels },
                      topologyKey: @topology_key,
                    },
                  },
                ],
              },
            }

            rebuild(resource, h)
          end
        end
      end
    end
  end
end
