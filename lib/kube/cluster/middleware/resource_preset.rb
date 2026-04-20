# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Cluster
    class Middleware
      # Reads the +app.kubernetes.io/size+ label from pod-bearing
      # resources and injects CPU/memory requests and limits into
      # every container.
      #
      # The label on the resource is the input:
      #
      #   Kube::Cluster["Deployment"].new {
      #     metadata.labels = { "app.kubernetes.io/size": "small" }
      #     ...
      #   }
      #
      # Register in the stack — no arguments needed:
      #
      #   stack do
      #     use Middleware::ResourcePreset
      #   end
      #
      # Available sizes: nano, micro, small, medium, large, xlarge, 2xlarge.
      # Limits are ~1.5x requests (following Bitnami conventions).
      #
      class ResourcePreset < Middleware
        LABEL = :"app.kubernetes.io/size"

        PRESETS = {
          "nano"    => { requests: { cpu: "100m",  memory: "128Mi"  }, limits: { cpu: "150m",  memory: "192Mi"  } },
          "micro"   => { requests: { cpu: "250m",  memory: "256Mi"  }, limits: { cpu: "375m",  memory: "384Mi"  } },
          "small"   => { requests: { cpu: "500m",  memory: "512Mi"  }, limits: { cpu: "750m",  memory: "768Mi"  } },
          "medium"  => { requests: { cpu: "500m",  memory: "1024Mi" }, limits: { cpu: "750m",  memory: "1536Mi" } },
          "large"   => { requests: { cpu: "1",     memory: "2048Mi" }, limits: { cpu: "1.5",   memory: "3072Mi" } },
          "xlarge"  => { requests: { cpu: "1",     memory: "3072Mi" }, limits: { cpu: "3",     memory: "6144Mi" } },
          "2xlarge" => { requests: { cpu: "1",     memory: "3072Mi" }, limits: { cpu: "6",     memory: "12288Mi" } },
        }.freeze

        def call(manifest)
          manifest.resources.map! do |resource|
            size = resource.label(LABEL)
            next resource unless size
            next resource unless resource.pod_bearing?

            preset = PRESETS.fetch(size.to_s) do
              raise ArgumentError, "Unknown size preset: #{size.inspect}. " \
                "Valid sizes: #{PRESETS.keys.join(', ')}"
            end

            h = resource.to_h
            pod_spec = resource.pod_template(h)
            next resource unless pod_spec

            resource.each_container(pod_spec) do |container|
              container[:resources] = deep_merge(preset, container[:resources] || {})
            end

            resource.rebuild(h)
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

  class ResourcePresetMiddlewareTest < Minitest::Test
    Middleware = Kube::Cluster::Middleware

    def test_injects_small_preset_into_deployment
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/size": "small" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      assert_equal "500m",   container.dig(:resources, :requests, :cpu)
      assert_equal "512Mi",  container.dig(:resources, :requests, :memory)
      assert_equal "750m",   container.dig(:resources, :limits, :cpu)
      assert_equal "768Mi",  container.dig(:resources, :limits, :memory)
    end

    def test_injects_nano_preset
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "tiny"
        metadata.labels = { "app.kubernetes.io/size": "nano" }
        spec.selector.matchLabels = { app: "tiny" }
        spec.template.metadata.labels = { app: "tiny" }
        spec.template.spec.containers = [
          { name: "app", image: "app:latest" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      assert_equal "100m",  container.dig(:resources, :requests, :cpu)
      assert_equal "128Mi", container.dig(:resources, :requests, :memory)
    end

    def test_injects_xlarge_preset
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "big"
        metadata.labels = { "app.kubernetes.io/size": "xlarge" }
        spec.selector.matchLabels = { app: "big" }
        spec.template.metadata.labels = { app: "big" }
        spec.template.spec.containers = [
          { name: "app", image: "app:latest" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      assert_equal "1",      container.dig(:resources, :requests, :cpu)
      assert_equal "3072Mi", container.dig(:resources, :requests, :memory)
      assert_equal "3",      container.dig(:resources, :limits, :cpu)
      assert_equal "6144Mi", container.dig(:resources, :limits, :memory)
    end

    def test_applies_to_all_containers
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "multi"
        metadata.labels = { "app.kubernetes.io/size": "micro" }
        spec.selector.matchLabels = { app: "multi" }
        spec.template.metadata.labels = { app: "multi" }
        spec.template.spec.containers = [
          { name: "app", image: "app:latest" },
          { name: "sidecar", image: "sidecar:latest" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      containers = m.resources.first.to_h.dig(:spec, :template, :spec, :containers)

      containers.each do |c|
        assert_equal "250m",  c.dig(:resources, :requests, :cpu)
        assert_equal "256Mi", c.dig(:resources, :requests, :memory)
      end
    end

    def test_skips_non_pod_bearing_resources
      resource = Kube::Cluster["ConfigMap"].new {
        metadata.name = "config"
        metadata.labels = { "app.kubernetes.io/size": "small" }
      }
      m = manifest(resource)

      Middleware::ResourcePreset.new.call(m)

      assert_equal resource.to_h, m.resources.first.to_h
    end

    def test_skips_resources_without_size_label
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      assert_nil container[:resources]
    end

    def test_raises_on_unknown_size
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/size": "potato" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      error = assert_raises(ArgumentError) do
        Middleware::ResourcePreset.new.call(m)
      end

      assert_includes error.message, "potato"
      assert_includes error.message, "Valid sizes"
    end

    def test_applies_to_statefulset
      m = manifest(Kube::Cluster["StatefulSet"].new {
        metadata.name = "db"
        metadata.labels = { "app.kubernetes.io/size": "medium" }
        spec.selector.matchLabels = { app: "db" }
        spec.template.metadata.labels = { app: "db" }
        spec.template.spec.containers = [
          { name: "postgres", image: "postgres:16" },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      assert_equal "500m",   container.dig(:resources, :requests, :cpu)
      assert_equal "1024Mi", container.dig(:resources, :requests, :memory)
    end

    def test_preserves_existing_container_resources_via_deep_merge
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/size": "small" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          {
            name: "web", image: "nginx:latest",
            resources: { requests: { cpu: "999m" } },
          },
        ]
      })

      Middleware::ResourcePreset.new.call(m)
      container = m.resources.first.to_h.dig(:spec, :template, :spec, :containers, 0)

      # The container's explicit value wins over the preset
      assert_equal "999m", container.dig(:resources, :requests, :cpu)
      # The preset fills in missing values
      assert_equal "512Mi", container.dig(:resources, :requests, :memory)
    end

    private

      def manifest(*resources)
        m = Kube::Cluster::Manifest.new
        resources.each { |r| m << r }
        m
      end
  end
end
