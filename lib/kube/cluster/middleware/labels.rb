# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Middleware
      # Merges labels into +metadata.labels+ on every resource.
      # Existing labels are preserved; the supplied labels act as defaults
      # that can be overridden per-resource.
      #
      #   stack do
      #     use Middleware::Labels, app: "web-app", managed_by: "kube_cluster"
      #   end
      #
      # The keyword arguments are converted to standard label keys:
      #
      #   app:        -> "app.kubernetes.io/name"
      #   instance:   -> "app.kubernetes.io/instance"
      #   version:    -> "app.kubernetes.io/version"
      #   component:  -> "app.kubernetes.io/component"
      #   part_of:    -> "app.kubernetes.io/part-of"
      #   managed_by: -> "app.kubernetes.io/managed-by"
      #
      # Any unrecognized keys are passed through as-is (string or symbol).
      #
      class Labels < Middleware
        STANDARD_KEYS = {
          app:        :"app.kubernetes.io/name",
          instance:   :"app.kubernetes.io/instance",
          version:    :"app.kubernetes.io/version",
          component:  :"app.kubernetes.io/component",
          part_of:    :"app.kubernetes.io/part-of",
          managed_by: :"app.kubernetes.io/managed-by",
        }.freeze

        def call(manifest)
          labels = normalize(@opts)

          manifest.resources.map! do |resource|
            filter(resource) do
              h = resource.to_h
              h[:metadata] ||= {}
              h[:metadata][:labels] = labels.merge(h[:metadata][:labels] || {})
              resource.rebuild(h)
            end
          end
        end

        private

          def normalize(labels)
            labels.each_with_object({}) do |(key, value), result|
              normalized_key = STANDARD_KEYS.fetch(key, key)
              result[normalized_key] = value.to_s
            end
          end
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  it "adds_standard_labels" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(app: "web", managed_by: "kube_cluster").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    labels[:"app.kubernetes.io/name"].should == "web"
  end

  it "maps_all_standard_keys" do
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

    labels[:"app.kubernetes.io/managed-by"].should == "kube_cluster"
  end

  it "resource_labels_override_middleware_defaults" do
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.labels = { "app.kubernetes.io/name": "override" }
    })

    Middleware::Labels.new(app: "default").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    labels[:"app.kubernetes.io/name"].should == "override"
  end

  it "preserves_existing_labels" do
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.labels = { custom: "value" }
    })

    Middleware::Labels.new(app: "web").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    labels[:custom].should == "value"
  end

  it "passes_through_non_standard_keys" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(:"team.io/name" => "platform").call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    labels[:"team.io/name"].should == "platform"
  end

  it "converts_values_to_strings" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Labels.new(version: 2).call(m)
    labels = m.resources.first.to_h.dig(:metadata, :labels)

    labels[:"app.kubernetes.io/version"].should == "2"
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
