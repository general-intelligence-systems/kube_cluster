# frozen_string_literal: true

require "test_helper"

class ServiceForDeploymentMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Manifest::Middleware

  def test_generates_service_from_deployment
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = { app: "web" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080, protocol: "TCP" }] },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    assert_instance_of Array, result
    assert_equal 2, result.size

    deploy, service = result
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
    resource = Kube::Schema["Deployment"].new {
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
    }

    result = Middleware::ServiceForDeployment.new.call(resource)
    service = result.last
    ports = service.to_h.dig(:spec, :ports)

    assert_equal 2, ports.size
    assert_equal "http", ports[0][:name]
    assert_equal "metrics", ports[1][:name]
  end

  def test_copies_labels_from_source
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/name": "web", "app.kubernetes.io/size": "small" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)
    service_labels = result.last.to_h.dig(:metadata, :labels)

    assert_equal "web", service_labels[:"app.kubernetes.io/name"]
    assert_equal "small", service_labels[:"app.kubernetes.io/size"]
  end

  def test_skips_deployment_without_named_ports
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ containerPort: 8080 }] },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    # No named ports → no Service generated, returns resource as-is
    assert_equal resource, result
  end

  def test_skips_deployment_without_ports
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "worker"
      spec.selector.matchLabels = { app: "worker" }
      spec.template.metadata.labels = { app: "worker" }
      spec.template.spec.containers = [
        { name: "worker", image: "worker:latest" },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    assert_equal resource, result
  end

  def test_skips_non_pod_bearing_resources
    resource = Kube::Schema["ConfigMap"].new {
      metadata.name = "config"
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    assert_equal resource, result
  end

  def test_skips_deployment_without_match_labels
    resource = Kube::Schema["Deployment"].new {
      metadata.name = "web"
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    assert_equal resource, result
  end

  def test_works_with_statefulset
    resource = Kube::Schema["StatefulSet"].new {
      metadata.name = "db"
      metadata.namespace = "database"
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16", ports: [{ name: "tcp-pg", containerPort: 5432 }] },
      ]
    }

    result = Middleware::ServiceForDeployment.new.call(resource)

    assert_instance_of Array, result
    assert_equal "Service", result.last.to_h[:kind]
    assert_equal "db", result.last.to_h.dig(:metadata, :name)
    assert_equal "database", result.last.to_h.dig(:metadata, :namespace)
  end
end
