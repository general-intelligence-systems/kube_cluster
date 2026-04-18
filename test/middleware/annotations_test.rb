# frozen_string_literal: true

require "test_helper"

class AnnotationsMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  def test_adds_annotations
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    result = Middleware::Annotations.new(
      "prometheus.io/scrape": "true",
      "prometheus.io/port": "9090",
    ).call(resource)

    annotations = result.to_h.dig(:metadata, :annotations)

    assert_equal "true", annotations[:"prometheus.io/scrape"]
    assert_equal "9090", annotations[:"prometheus.io/port"]
  end

  def test_resource_annotations_override_middleware_defaults
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
      metadata.annotations = { "prometheus.io/port": "8080" }
    }

    result = Middleware::Annotations.new("prometheus.io/port": "9090").call(resource)
    annotations = result.to_h.dig(:metadata, :annotations)

    assert_equal "8080", annotations[:"prometheus.io/port"]
  end

  def test_preserves_existing_annotations
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
      metadata.annotations = { "custom/annotation": "keep" }
    }

    result = Middleware::Annotations.new("prometheus.io/scrape": "true").call(resource)
    annotations = result.to_h.dig(:metadata, :annotations)

    assert_equal "keep", annotations[:"custom/annotation"]
    assert_equal "true", annotations[:"prometheus.io/scrape"]
  end

  def test_converts_values_to_strings
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "test"
    }

    result = Middleware::Annotations.new("prometheus.io/port": 9090).call(resource)
    annotations = result.to_h.dig(:metadata, :annotations)

    assert_equal "9090", annotations[:"prometheus.io/port"]
  end
end
