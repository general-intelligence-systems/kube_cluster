# frozen_string_literal: true

require "test_helper"

class NamespaceMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  def test_sets_namespace_on_configmap
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    result = Middleware::Namespace.new("production").call(resource)

    assert_equal "production", result.to_h.dig(:metadata, :namespace)
  end

  def test_sets_namespace_on_deployment
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
    }

    result = Middleware::Namespace.new("staging").call(resource)

    assert_equal "staging", result.to_h.dig(:metadata, :namespace)
  end

  def test_skips_namespace_resource
    resource = Kube::Schema["Namespace"].new {
      metadata.name = "my-ns"
    }

    result = Middleware::Namespace.new("production").call(resource)

    assert_nil result.to_h.dig(:metadata, :namespace)
  end

  def test_skips_cluster_role
    resource = Kube::Schema["ClusterRole"].new {
      metadata.name = "admin"
    }

    result = Middleware::Namespace.new("production").call(resource)

    assert_nil result.to_h.dig(:metadata, :namespace)
  end

  def test_skips_cluster_role_binding
    resource = Kube::Schema["ClusterRoleBinding"].new {
      metadata.name = "admin-binding"
    }

    result = Middleware::Namespace.new("production").call(resource)

    assert_nil result.to_h.dig(:metadata, :namespace)
  end

  def test_overwrites_existing_namespace
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
      metadata.namespace = "old"
    }

    result = Middleware::Namespace.new("new").call(resource)

    assert_equal "new", result.to_h.dig(:metadata, :namespace)
  end

  def test_returns_new_resource_instance
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    result = Middleware::Namespace.new("production").call(resource)

    refute_same resource, result
  end
end
