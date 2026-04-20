# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Cluster
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

        def call(manifest)
          manifest.resources.map! do |resource|
            next resource unless resource.pod_bearing?

            h = resource.to_h
            pod_spec = resource.pod_template(h)
            next resource unless pod_spec

            # Don't overwrite existing affinity configuration.
            next resource if pod_spec[:affinity]

            match_labels = h.dig(:spec, :selector, :matchLabels)
            next resource unless match_labels && !match_labels.empty?

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

            resource.rebuild(h)
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

  class PodAntiAffinityMiddlewareTest < Minitest::Test
    Middleware = Kube::Cluster::Middleware

    def test_injects_soft_anti_affinity_on_deployment
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web", instance: "prod" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::PodAntiAffinity.new.call(m)
      affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

      paa = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution)
      assert_equal 1, paa.size

      term = paa.first
      assert_equal 1, term[:weight]
      assert_equal "kubernetes.io/hostname", term.dig(:podAffinityTerm, :topologyKey)
      assert_equal({ app: "web", instance: "prod" }, term.dig(:podAffinityTerm, :labelSelector, :matchLabels))
    end

    def test_custom_topology_key
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::PodAntiAffinity.new(
        topology_key: "topology.kubernetes.io/zone",
      ).call(m)

      affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)
      term = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

      assert_equal "topology.kubernetes.io/zone", term.dig(:podAffinityTerm, :topologyKey)
    end

    def test_custom_weight
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::PodAntiAffinity.new(weight: 100).call(m)
      term = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity,
        :podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

      assert_equal 100, term[:weight]
    end

    def test_skips_resources_with_existing_affinity
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.affinity = { nodeAffinity: { custom: true } }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::PodAntiAffinity.new.call(m)
      affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

      assert_equal({ nodeAffinity: { custom: true } }, affinity)
    end

    def test_skips_non_pod_bearing_resources
      resource = Kube::Cluster["ConfigMap"].new { metadata.name = "config" }
      m = manifest(resource)

      Middleware::PodAntiAffinity.new.call(m)

      assert_equal resource.to_h, m.resources.first.to_h
    end

    def test_skips_resources_without_match_labels
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::PodAntiAffinity.new.call(m)
      affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

      assert_nil affinity
    end

    def test_applies_to_statefulset
      m = manifest(Kube::Cluster["StatefulSet"].new {
        metadata.name = "db"
        spec.selector.matchLabels = { app: "db" }
        spec.template.metadata.labels = { app: "db" }
        spec.template.spec.containers = [
          { name: "postgres", image: "postgres:16" },
        ]
      })

      Middleware::PodAntiAffinity.new.call(m)
      affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

      refute_nil affinity.dig(:podAntiAffinity)
    end

    private

      def manifest(*resources)
        m = Kube::Cluster::Manifest.new
        resources.each { |r| m << r }
        m
      end
  end
end
