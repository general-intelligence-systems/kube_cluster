# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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
        def call(manifest)
          annotations = @opts.transform_keys(&:to_sym).transform_values(&:to_s)

          manifest.resources.map! do |resource|
            filter(resource) do
              h = resource.to_h
              h[:metadata] ||= {}
              h[:metadata][:annotations] = annotations.merge(h[:metadata][:annotations] || {})
              resource.rebuild(h)
            end
          end
        end
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  it "adds_annotations" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Annotations.new(
      "prometheus.io/scrape": "true",
      "prometheus.io/port": "9090",
    ).call(m)

    annotations = m.resources.first.to_h.dig(:metadata, :annotations)

    annotations[:"prometheus.io/port"].should == "9090"
  end

  it "resource_annotations_override_middleware_defaults" do
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.annotations = { "prometheus.io/port": "8080" }
    })

    Middleware::Annotations.new("prometheus.io/port": "9090").call(m)
    annotations = m.resources.first.to_h.dig(:metadata, :annotations)

    annotations[:"prometheus.io/port"].should == "8080"
  end

  it "preserves_existing_annotations" do
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.annotations = { "custom/annotation": "keep" }
    })

    Middleware::Annotations.new("prometheus.io/scrape": "true").call(m)
    annotations = m.resources.first.to_h.dig(:metadata, :annotations)

    annotations[:"prometheus.io/scrape"].should == "true"
  end

  it "converts_values_to_strings" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Annotations.new("prometheus.io/port": 9090).call(m)
    annotations = m.resources.first.to_h.dig(:metadata, :annotations)

    annotations[:"prometheus.io/port"].should == "9090"
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
