# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Cluster
    class Middleware
      # Merges annotations into +metadata.annotations+ on every resource.
      # Existing annotations are preserved; the supplied annotations act
      # as defaults that can be overridden per-resource.
      #
      #   stack do
      #     use Middleware::Annotations,
      #       "prometheus.io/scrape": "true",
      #       "prometheus.io/port":   "9090"
      #   end
      #
      class Annotations < Middleware
        def initialize(**annotations)
          @annotations = annotations.transform_keys(&:to_sym).transform_values(&:to_s)
        end

        def call(manifest)
          manifest.resources.map! do |resource|
            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:annotations] = @annotations.merge(h[:metadata][:annotations] || {})
            resource.rebuild(h)
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

  class AnnotationsMiddlewareTest < Minitest::Test
    Middleware = Kube::Cluster::Middleware

    def test_adds_annotations
      m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

      Middleware::Annotations.new(
        "prometheus.io/scrape": "true",
        "prometheus.io/port": "9090",
      ).call(m)

      annotations = m.resources.first.to_h.dig(:metadata, :annotations)

      assert_equal "true", annotations[:"prometheus.io/scrape"]
      assert_equal "9090", annotations[:"prometheus.io/port"]
    end

    def test_resource_annotations_override_middleware_defaults
      m = manifest(Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
        metadata.annotations = { "prometheus.io/port": "8080" }
      })

      Middleware::Annotations.new("prometheus.io/port": "9090").call(m)
      annotations = m.resources.first.to_h.dig(:metadata, :annotations)

      assert_equal "8080", annotations[:"prometheus.io/port"]
    end

    def test_preserves_existing_annotations
      m = manifest(Kube::Cluster["ConfigMap"].new {
        metadata.name = "test"
        metadata.annotations = { "custom/annotation": "keep" }
      })

      Middleware::Annotations.new("prometheus.io/scrape": "true").call(m)
      annotations = m.resources.first.to_h.dig(:metadata, :annotations)

      assert_equal "keep", annotations[:"custom/annotation"]
      assert_equal "true", annotations[:"prometheus.io/scrape"]
    end

    def test_converts_values_to_strings
      m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

      Middleware::Annotations.new("prometheus.io/port": 9090).call(m)
      annotations = m.resources.first.to_h.dig(:metadata, :annotations)

      assert_equal "9090", annotations[:"prometheus.io/port"]
    end

    private

      def manifest(*resources)
        m = Kube::Cluster::Manifest.new
        resources.each { |r| m << r }
        m
      end
  end
end
