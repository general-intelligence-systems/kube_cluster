# frozen_string_literal: true

require "test_helper"

class HPAForDeploymentMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Middleware

  def test_generates_hpa_from_deployment
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = {
        "app.kubernetes.io/name": "web",
        "app.kubernetes.io/autoscale": "2-10",
      }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    Middleware::HPAForDeployment.new.call(m)

    assert_equal 2, m.resources.size

    deploy, hpa = m.resources
    assert_equal "Deployment", deploy.to_h[:kind]
    assert_equal "HorizontalPodAutoscaler", hpa.to_h[:kind]

    hh = hpa.to_h
    assert_equal "web", hh.dig(:metadata, :name)
    assert_equal "production", hh.dig(:metadata, :namespace)
    assert_equal 2, hh.dig(:spec, :minReplicas)
    assert_equal 10, hh.dig(:spec, :maxReplicas)

    ref = hh.dig(:spec, :scaleTargetRef)
    assert_equal "apps/v1", ref[:apiVersion]
    assert_equal "Deployment", ref[:kind]
    assert_equal "web", ref[:name]

    metrics = hh.dig(:spec, :metrics)
    assert_equal 2, metrics.size
    assert_equal "cpu", metrics[0].dig(:resource, :name)
    assert_equal 75, metrics[0].dig(:resource, :target, :averageUtilization)
    assert_equal "memory", metrics[1].dig(:resource, :name)
    assert_equal 80, metrics[1].dig(:resource, :target, :averageUtilization)
  end

  def test_custom_cpu_and_memory_targets
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/autoscale": "1-3" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    Middleware::HPAForDeployment.new(cpu: 60, memory: 70).call(m)
    hpa = m.resources.last.to_h

    assert_equal 60, hpa.dig(:spec, :metrics, 0, :resource, :target, :averageUtilization)
    assert_equal 70, hpa.dig(:spec, :metrics, 1, :resource, :target, :averageUtilization)
  end

  def test_strips_autoscale_label_from_hpa
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = {
        "app.kubernetes.io/name": "web",
        "app.kubernetes.io/autoscale": "1-5",
      }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    Middleware::HPAForDeployment.new.call(m)
    hpa_labels = m.resources.last.to_h.dig(:metadata, :labels)

    assert_nil hpa_labels[:"app.kubernetes.io/autoscale"]
    assert_equal "web", hpa_labels[:"app.kubernetes.io/name"]
  end

  def test_skips_deployment_without_autoscale_label
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    Middleware::HPAForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_skips_non_pod_bearing_resources
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "config"
      metadata.labels = { "app.kubernetes.io/autoscale": "1-5" }
    })

    Middleware::HPAForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_raises_on_invalid_range_format
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/autoscale": "bad" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    error = assert_raises(ArgumentError) do
      Middleware::HPAForDeployment.new.call(m)
    end

    assert_includes error.message, "Invalid autoscale label"
  end

  def test_raises_on_invalid_range_values
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/autoscale": "5-2" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx" },
      ]
    })

    error = assert_raises(ArgumentError) do
      Middleware::HPAForDeployment.new.call(m)
    end

    assert_includes error.message, "Invalid autoscale range"
  end

  def test_works_with_statefulset
    m = manifest(Kube::Cluster["StatefulSet"].new {
      metadata.name = "db"
      metadata.labels = { "app.kubernetes.io/autoscale": "1-3" }
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16" },
      ]
    })

    Middleware::HPAForDeployment.new.call(m)

    assert_equal 2, m.resources.size
    hpa = m.resources.last.to_h
    assert_equal "StatefulSet", hpa.dig(:spec, :scaleTargetRef, :kind)
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
