# frozen_string_literal: true

require "test_helper"

class PodAntiAffinityMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  def test_injects_soft_anti_affinity_on_deployment
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web", instance: "prod" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::PodAntiAffinity.new.call(resource)
    affinity = result.to_h.dig(:spec, :template, :spec, :affinity)

    paa = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution)
    assert_equal 1, paa.size

    term = paa.first
    assert_equal 1, term[:weight]
    assert_equal "kubernetes.io/hostname", term.dig(:podAffinityTerm, :topologyKey)
    assert_equal({ app: "web", instance: "prod" }, term.dig(:podAffinityTerm, :labelSelector, :matchLabels))
  end

  def test_custom_topology_key
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::PodAntiAffinity.new(
      topology_key: "topology.kubernetes.io/zone",
    ).call(resource)

    affinity = result.to_h.dig(:spec, :template, :spec, :affinity)
    term = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

    assert_equal "topology.kubernetes.io/zone", term.dig(:podAffinityTerm, :topologyKey)
  end

  def test_custom_weight
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::PodAntiAffinity.new(weight: 100).call(resource)
    term = result.to_h.dig(:spec, :template, :spec, :affinity,
      :podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

    assert_equal 100, term[:weight]
  end

  def test_skips_resources_with_existing_affinity
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.affinity = { nodeAffinity: { custom: true } }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::PodAntiAffinity.new.call(resource)
    affinity = result.to_h.dig(:spec, :template, :spec, :affinity)

    assert_equal({ nodeAffinity: { custom: true } }, affinity)
  end

  def test_skips_non_pod_bearing_resources
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "config"
    }

    result = Middleware::PodAntiAffinity.new.call(resource)

    assert_equal resource.to_h, result.to_h
  end

  def test_skips_resources_without_match_labels
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    }

    result = Middleware::PodAntiAffinity.new.call(resource)
    affinity = result.to_h.dig(:spec, :template, :spec, :affinity)

    assert_nil affinity
  end

  def test_applies_to_statefulset
    resource = Kube::Schema["StatefulSet"].new {
      metadata.name = "db"
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16" },
      ]
    }

    result = Middleware::PodAntiAffinity.new.call(resource)
    affinity = result.to_h.dig(:spec, :template, :spec, :affinity)

    refute_nil affinity.dig(:podAntiAffinity)
  end
end
