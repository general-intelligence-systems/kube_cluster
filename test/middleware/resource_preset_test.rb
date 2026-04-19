# frozen_string_literal: true

require "test_helper"

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
