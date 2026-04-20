# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Cluster
    # A flat, ordered collection of Kubernetes resources.
    #
    # Manifest is a pure resource collection. Middleware is applied
    # separately via Kube::Cluster::Middleware::Stack.
    #
    #   manifest = Kube::Cluster::Manifest.new
    #   manifest << Kube::Cluster["Deployment"].new { ... }
    #
    #   stack = Kube::Cluster::Middleware::Stack.new do
    #     use Middleware::Namespace, "production"
    #     use Middleware::Labels, app: "web-app"
    #   end
    #
    #   stack.call(manifest)
    #   manifest.to_yaml
    #
    class Manifest < Kube::Schema::Manifest
      attr_reader :resources
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

  class ManifestTest < Minitest::Test
    Middleware = Kube::Cluster::Middleware

    # ── Bare manifest ────────────────────────────────────────────────────────

    def test_bare_manifest_enumerates_resources_unchanged
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
        self.data = { key: "value" }
      }

      resources = m.to_a
      assert_equal 1, resources.size
      assert_equal "ConfigMap", resources.first.to_h[:kind]
      assert_equal "test", resources.first.to_h.dig(:metadata, :name)
    end

    # ── Stack transforms resources ───────────────────────────────────────────

    def test_stack_transforms_resources
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
      }

      stack = Middleware::Stack.new do
        use Middleware::Namespace, "production"
      end
      stack.call(m)

      resources = m.to_a
      assert_equal "production", resources.first.to_h.dig(:metadata, :namespace)
    end

    def test_to_yaml_reflects_middleware
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
      }

      Middleware::Namespace.new("production").call(m)

      yaml = m.to_yaml
      assert_includes yaml, "namespace: production"
    end

    def test_enumerable_methods_work
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new { metadata.name = "a" }
      m << Kube::Cluster["ConfigMap"].new { metadata.name = "b" }

      Middleware::Namespace.new("production").call(m)

      names = m.map { |r| r.to_h.dig(:metadata, :name) }
      assert_equal %w[a b], names

      all_namespaced = m.all? { |r| r.to_h.dig(:metadata, :namespace) == "production" }
      assert all_namespaced
    end

    # ── Multi-middleware stack ──────────────────────────────────────────────

    def test_multiple_middleware_compose_in_order
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
      }

      stack = Middleware::Stack.new do
        use Middleware::Namespace, "staging"
        use Middleware::Labels, app: "myapp", managed_by: "kube_cluster"
      end
      stack.call(m)

      r = m.first
      h = r.to_h

      assert_equal "staging", h.dig(:metadata, :namespace)
      assert_equal "myapp", h.dig(:metadata, :labels, :"app.kubernetes.io/name")
      assert_equal "kube_cluster", h.dig(:metadata, :labels, :"app.kubernetes.io/managed-by")
    end

    # ── size reflects resource count ─────────────────────────────────────────

    def test_size_reflects_resource_count
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new { metadata.name = "a" }
      m << Kube::Cluster["ConfigMap"].new { metadata.name = "b" }

      assert_equal 2, m.size
      assert_equal 2, m.length
    end

    # ── each without block ──────────────────────────────────────────────────

    def test_each_without_block_returns_enumerator
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

      Middleware::Namespace.new("production").call(m)

      enum = m.each
      assert_instance_of Enumerator, enum

      r = enum.first
      assert_equal "production", r.to_h.dig(:metadata, :namespace)
    end

    # ── Generative middleware produces new resources ─────────────────────────

    def test_generative_middleware_adds_service
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.namespace = "default"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
        ]
      }

      Middleware::ServiceForDeployment.new.call(m)

      kinds = m.map { |r| r.to_h[:kind] }
      assert_equal %w[Deployment Service], kinds
    end

    def test_generative_middleware_does_not_affect_non_matching_resources
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["ConfigMap"].new {
        metadata.name = "config"
      }

      Middleware::ServiceForDeployment.new.call(m)

      resources = m.to_a
      assert_equal 1, resources.size
      assert_equal "ConfigMap", resources.first.to_h[:kind]
    end

    # ── Generated resources flow through subsequent middleware stages ────────

    def test_generated_resources_flow_through_subsequent_stages
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
        ]
      }

      stack = Middleware::Stack.new do
        use Middleware::ServiceForDeployment           # generates Service
        use Middleware::Namespace, "production"         # namespaces everything
        use Middleware::Labels, managed_by: "middleware" # labels everything
      end
      stack.call(m)

      resources = m.to_a
      assert_equal 2, resources.size

      # Both the Deployment and the generated Service got namespaced and labeled
      resources.each do |r|
        h = r.to_h
        assert_equal "production", h.dig(:metadata, :namespace),
          "Expected #{h[:kind]} to be namespaced"
        assert_equal "middleware", h.dig(:metadata, :labels, :"app.kubernetes.io/managed-by"),
          "Expected #{h[:kind]} to be labeled"
      end
    end

    # ── YAML serializes integers correctly ──────────────────────────────────

    def test_to_yaml_serializes_integers_as_plain_values
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
        ]
      }

      yaml = m.to_yaml
      refute_includes yaml, "!ruby/object:Integer",
        "Integer values must serialize as plain YAML numbers, not !ruby/object:Integer"
      assert_includes yaml, "containerPort: 8080"
    end

    # ── Multi-generative: chained generation ────────────────────────────────

    def test_chained_generative_middleware
      m = Kube::Cluster::Manifest.new
      m << Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.namespace = "default"
        metadata.labels = {
          "app.kubernetes.io/expose":    "app.example.com",
          "app.kubernetes.io/autoscale": "2-10",
        }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
        ]
      }

      stack = Middleware::Stack.new do
        use Middleware::ServiceForDeployment   # Deployment → +Service
        use Middleware::IngressForService       # Service with expose label → +Ingress
        use Middleware::HPAForDeployment        # Deployment with autoscale label → +HPA
      end
      stack.call(m)

      kinds = m.map { |r| r.to_h[:kind] }

      assert_includes kinds, "Deployment"
      assert_includes kinds, "Service"
      assert_includes kinds, "Ingress"
      assert_includes kinds, "HorizontalPodAutoscaler"
      assert_equal 4, m.to_a.size
    end
  end
end
