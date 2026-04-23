# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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

test do
  Middleware = Kube::Cluster::Middleware

  it "injects_small_preset_into_deployment" do
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

    container.dig(:resources, :requests, :cpu).should == "500m"
  end

  it "injects_nano_preset" do
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

    container.dig(:resources, :requests, :cpu).should == "100m"
  end

  it "injects_xlarge_preset" do
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

    container.dig(:resources, :limits, :cpu).should == "3"
  end

  it "applies_to_all_containers" do
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

    containers.last.dig(:resources, :requests, :cpu).should == "250m"
  end

  it "skips_non_pod_bearing_resources" do
    resource = Kube::Cluster["ConfigMap"].new {
      metadata.name = "config"
      metadata.labels = { "app.kubernetes.io/size": "small" }
    }
    m = manifest(resource)

    Middleware::ResourcePreset.new.call(m)

    m.resources.first.to_h.should == resource.to_h
  end

  it "skips_resources_without_size_label" do
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

    container[:resources].should.be.nil
  end

  it "raises_on_unknown_size" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/size": "potato" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    lambda { Middleware::ResourcePreset.new.call(m) }.should.raise ArgumentError
  end

  it "applies_to_statefulset" do
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

    container.dig(:resources, :requests, :cpu).should == "500m"
  end

  it "preserves_existing_container_resources_via_deep_merge" do
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
    container.dig(:resources, :requests, :cpu).should == "999m"
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
