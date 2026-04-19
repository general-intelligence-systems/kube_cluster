# frozen_string_literal: true

require "test_helper"

class LabelsMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Middleware

  def test_adds_standard_labels
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(app: "web", managed_by: "kube_cluster").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "web", labels[:"app.kubernetes.io/name"]
    assert_equal "kube_cluster", labels[:"app.kubernetes.io/managed-by"]
  end

  def test_maps_all_standard_keys
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(
      app: "web",
      instance: "my-release",
      version: "1.0.0",
      component: "frontend",
      part_of: "platform",
      managed_by: "kube_cluster",
    ).call(m)

    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "web",           labels[:"app.kubernetes.io/name"]
    assert_equal "my-release",    labels[:"app.kubernetes.io/instance"]
    assert_equal "1.0.0",         labels[:"app.kubernetes.io/version"]
    assert_equal "frontend",      labels[:"app.kubernetes.io/component"]
    assert_equal "platform",      labels[:"app.kubernetes.io/part-of"]
    assert_equal "kube_cluster",  labels[:"app.kubernetes.io/managed-by"]
  end

  def test_resource_labels_override_middleware_defaults
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.labels = { "app.kubernetes.io/name": "override" }
    })

    Middleware::Labels.new(app: "default").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "override", labels[:"app.kubernetes.io/name"]
  end

  def test_preserves_existing_labels
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.labels = { custom: "value" }
    })

    Middleware::Labels.new(app: "web").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "value", labels[:custom]
    assert_equal "web", labels[:"app.kubernetes.io/name"]
  end

  def test_passes_through_non_standard_keys
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(:"team.io/name" => "platform").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "platform", labels[:"team.io/name"]
  end

  def test_converts_values_to_strings
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(version: 2).call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    assert_equal "2", labels[:"app.kubernetes.io/version"]
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
