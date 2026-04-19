# frozen_string_literal: true

require "test_helper"

class ManifestTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  # ── Subclass with no stack ────────────────────────────────────────────────

  class BareManifest < Kube::Cluster::Manifest; end

  def test_bare_manifest_enumerates_resources_unchanged
    m = BareManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
      self.data = { key: "value" }
    }

    resources = m.to_a
    assert_equal 1, resources.size
    assert_equal "ConfigMap", resources.first.to_h[:kind]
    assert_equal "test", resources.first.to_h.dig(:metadata, :name)
  end

  # ── Subclass with a stack ─────────────────────────────────────────────────

  class NamespacedManifest < Kube::Cluster::Manifest
    stack do
      use Middleware::Namespace, "production"
    end
  end

  def test_stack_transforms_resources_on_enumeration
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    resources = m.to_a
    assert_equal "production", resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_to_yaml_goes_through_middleware
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    yaml = m.to_yaml
    assert_includes yaml, "namespace: production"
  end

  def test_each_yields_transformed_resources
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    namespaces = []
    m.each { |r| namespaces << r.to_h.dig(:metadata, :namespace) }
    assert_equal ["production"], namespaces
  end

  def test_enumerable_methods_go_through_middleware
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new { metadata.name = "a" }
    m << Kube::Schema["ConfigMap"].new { metadata.name = "b" }

    names = m.map { |r| r.to_h.dig(:metadata, :name) }
    assert_equal %w[a b], names

    all_namespaced = m.all? { |r| r.to_h.dig(:metadata, :namespace) == "production" }
    assert all_namespaced
  end

  # ── Multi-middleware stack ────────────────────────────────────────────────

  class FullStackManifest < Kube::Cluster::Manifest
    stack do
      use Middleware::Namespace, "staging"
      use Middleware::Labels, app: "myapp", managed_by: "kube_cluster"
    end
  end

  def test_multiple_middleware_compose_in_order
    m = FullStackManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    r = m.first
    h = r.to_h

    assert_equal "staging", h.dig(:metadata, :namespace)
    assert_equal "myapp", h.dig(:metadata, :labels, :"app.kubernetes.io/name")
    assert_equal "kube_cluster", h.dig(:metadata, :labels, :"app.kubernetes.io/managed-by")
  end

  # ── Raw @resources are not mutated ────────────────────────────────────────

  def test_raw_resources_are_not_mutated
    m = NamespacedManifest.new
    cm = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }
    m << cm

    # Enumerate to trigger middleware
    m.to_a

    # Original resource should not have namespace
    assert_nil cm.to_h.dig(:metadata, :namespace)
  end

  # ── size reflects raw count ───────────────────────────────────────────────

  def test_size_reflects_raw_resource_count
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new { metadata.name = "a" }
    m << Kube::Schema["ConfigMap"].new { metadata.name = "b" }

    assert_equal 2, m.size
    assert_equal 2, m.length
  end

  # ── enum_for without block ────────────────────────────────────────────────

  def test_each_without_block_returns_enumerator
    m = NamespacedManifest.new
    m << Kube::Schema["ConfigMap"].new { metadata.name = "test" }

    enum = m.each
    assert_instance_of Enumerator, enum

    r = enum.first
    assert_equal "production", r.to_h.dig(:metadata, :namespace)
  end

  # ── Generative middleware produces new resources ──────────────────────────

  class GenerativeManifest < Kube::Cluster::Manifest
    stack do
      use Middleware::ServiceForDeployment
    end
  end

  def test_generative_middleware_adds_service
    m = GenerativeManifest.new
    m << Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "default"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    resources = m.to_a
    kinds = resources.map { |r| r.to_h[:kind] }

    assert_equal %w[Deployment Service], kinds
  end

  def test_generative_middleware_does_not_affect_non_matching_resources
    m = GenerativeManifest.new
    m << Kube::Schema["ConfigMap"].new {
      metadata.name = "config"
    }

    resources = m.to_a
    assert_equal 1, resources.size
    assert_equal "ConfigMap", resources.first.to_h[:kind]
  end

  # ── Generated resources flow through subsequent middleware stages ─────────

  class GenerativeThenTransformManifest < Kube::Cluster::Manifest
    stack do
      use Middleware::ServiceForDeployment           # generates Service
      use Middleware::Namespace, "production"         # namespaces everything
      use Middleware::Labels, managed_by: "middleware" # labels everything
    end
  end

  def test_generated_resources_flow_through_subsequent_stages
    m = GenerativeThenTransformManifest.new
    m << Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

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
    m = BareManifest.new
    m << Kube::Schema["Deployment"].new {
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

  # ── Multi-generative: chained generation ─────────────────────────────────

  class ChainedGenerativeManifest < Kube::Cluster::Manifest
    stack do
      use Middleware::ServiceForDeployment   # Deployment → [Deployment, Service]
      use Middleware::IngressForService       # Service with expose label → [Service, Ingress]
      use Middleware::HPAForDeployment        # Deployment with autoscale label → [Deployment, HPA]
    end
  end

  def test_chained_generative_middleware
    m = ChainedGenerativeManifest.new
    m << Kube::Schema["Deployment"].new {
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

    resources = m.to_a
    kinds = resources.map { |r| r.to_h[:kind] }

    # Deployment → ServiceForDeployment → [Deployment, Service]
    # Service has expose label (copied from Deployment) → IngressForService → [Service, Ingress]
    # Deployment has autoscale label → HPAForDeployment → [Deployment, HPA]
    assert_includes kinds, "Deployment"
    assert_includes kinds, "Service"
    assert_includes kinds, "Ingress"
    assert_includes kinds, "HorizontalPodAutoscaler"
    assert_equal 4, resources.size
  end
end
