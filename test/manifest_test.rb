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
end
