# frozen_string_literal: true

require "test_helper"

class NamespaceMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Middleware

  def test_sets_namespace_on_configmap
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Namespace.new("production").call(m)

    assert_equal "production", m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_sets_namespace_on_deployment
    m = manifest(Kube::Cluster["Deployment"].new { metadata.name = "web" })

    Middleware::Namespace.new("staging").call(m)

    assert_equal "staging", m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_skips_namespace_resource
    m = manifest(Kube::Cluster["Namespace"].new { metadata.name = "my-ns" })

    Middleware::Namespace.new("production").call(m)

    assert_nil m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_skips_cluster_role
    m = manifest(Kube::Cluster["ClusterRole"].new { metadata.name = "admin" })

    Middleware::Namespace.new("production").call(m)

    assert_nil m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_skips_cluster_role_binding
    m = manifest(Kube::Cluster["ClusterRoleBinding"].new { metadata.name = "admin-binding" })

    Middleware::Namespace.new("production").call(m)

    assert_nil m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_overwrites_existing_namespace
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.namespace = "old"
    })

    Middleware::Namespace.new("new").call(m)

    assert_equal "new", m.resources.first.to_h.dig(:metadata, :namespace)
  end

  def test_returns_new_resource_instance
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }
    m = manifest(resource)

    Middleware::Namespace.new("production").call(m)

    refute_same resource, m.resources.first
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
