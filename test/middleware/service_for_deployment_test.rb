# frozen_string_literal: true

require "test_helper"

class ServiceForDeploymentMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Middleware

  def test_generates_service_from_deployment
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = { app: "web" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080, protocol: "TCP" }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 2, m.resources.size

    deploy, service = m.resources
    assert_equal "Deployment", deploy.to_h[:kind]
    assert_equal "Service", service.to_h[:kind]

    sh = service.to_h
    assert_equal "web", sh.dig(:metadata, :name)
    assert_equal "production", sh.dig(:metadata, :namespace)
    assert_equal({ app: "web" }, sh.dig(:spec, :selector))

    port = sh.dig(:spec, :ports, 0)
    assert_equal "http", port[:name]
    assert_equal 8080, port[:port]
    assert_equal "http", port[:targetPort]
    assert_equal "TCP", port[:protocol]
  end

  def test_maps_multiple_ports
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        {
          name: "web", image: "nginx",
          ports: [
            { name: "http", containerPort: 8080 },
            { name: "metrics", containerPort: 9090 },
          ],
        },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)
    service = m.resources.last
    ports = service.to_h.dig(:spec, :ports)

    assert_equal 2, ports.size
    assert_equal "http", ports[0][:name]
    assert_equal "metrics", ports[1][:name]
  end

  def test_copies_labels_from_source
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/name": "web", "app.kubernetes.io/size": "small" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)
    service_labels = m.resources.last.to_h.dig(:metadata, :labels)

    assert_equal "web", service_labels[:"app.kubernetes.io/name"]
    assert_equal "small", service_labels[:"app.kubernetes.io/size"]
  end

  def test_skips_deployment_without_named_ports
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_skips_deployment_without_ports
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "worker"
      spec.selector.matchLabels = { app: "worker" }
      spec.template.metadata.labels = { app: "worker" }
      spec.template.spec.containers = [
        { name: "worker", image: "worker:latest" },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_skips_non_pod_bearing_resources
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "config" })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_skips_deployment_without_match_labels
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_works_with_statefulset
    m = manifest(Kube::Cluster["StatefulSet"].new {
      metadata.name = "db"
      metadata.namespace = "database"
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16", ports: [{ name: "tcp-pg", containerPort: 5432 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    assert_equal 2, m.resources.size
    assert_equal "Service", m.resources.last.to_h[:kind]
    assert_equal "db", m.resources.last.to_h.dig(:metadata, :name)
    assert_equal "database", m.resources.last.to_h.dig(:metadata, :namespace)
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
