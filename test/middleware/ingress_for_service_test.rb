# frozen_string_literal: true

require "test_helper"

class IngressForServiceMiddlewareTest < Minitest::Test
  Middleware = Kube::Cluster::Middleware

  def test_generates_ingress_from_service_with_expose_label
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
      spec.selector = { app: "web" }
      spec.ports = [{ name: "http", port: 80, targetPort: "http" }]
    })

    Middleware::IngressForService.new.call(m)

    assert_equal 2, m.resources.size

    service, ingress = m.resources
    assert_equal "Service", service.to_h[:kind]
    assert_equal "Ingress", ingress.to_h[:kind]

    ih = ingress.to_h
    assert_equal "web", ih.dig(:metadata, :name)
    assert_equal "production", ih.dig(:metadata, :namespace)
    assert_equal "nginx", ih.dig(:spec, :ingressClassName)
    assert_equal "letsencrypt-prod", ih.dig(:metadata, :annotations, :"cert-manager.io/cluster-issuer")
    assert_equal "true", ih.dig(:metadata, :annotations, :"nginx.ingress.kubernetes.io/ssl-redirect")

    # TLS
    tls = ih.dig(:spec, :tls, 0)
    assert_equal ["app.example.com"], tls[:hosts]
    assert_equal "web-tls", tls[:secretName]

    # Rules
    rule = ih.dig(:spec, :rules, 0)
    assert_equal "app.example.com", rule[:host]
    assert_equal "web", rule.dig(:http, :paths, 0, :backend, :service, :name)
    assert_equal "http", rule.dig(:http, :paths, 0, :backend, :service, :port, :name)
  end

  def test_custom_issuer_and_ingress_class
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new(
      issuer: "letsencrypt-staging",
      ingress_class: "traefik",
    ).call(m)

    ingress = m.resources.last.to_h
    assert_equal "traefik", ingress.dig(:spec, :ingressClassName)
    assert_equal "letsencrypt-staging", ingress.dig(:metadata, :annotations, :"cert-manager.io/cluster-issuer")
  end

  def test_expose_true_uses_name_as_hostname
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "api"
      metadata.labels = { "app.kubernetes.io/expose": "true" }
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new.call(m)
    ingress = m.resources.last.to_h

    assert_equal "api.local", ingress.dig(:spec, :rules, 0, :host)
    assert_equal ["api.local"], ingress.dig(:spec, :tls, 0, :hosts)
  end

  def test_strips_expose_label_from_ingress
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      metadata.labels = {
        "app.kubernetes.io/expose": "app.example.com",
        "app.kubernetes.io/name": "web",
      }
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new.call(m)
    ingress_labels = m.resources.last.to_h.dig(:metadata, :labels)

    assert_nil ingress_labels[:"app.kubernetes.io/expose"]
    assert_equal "web", ingress_labels[:"app.kubernetes.io/name"]
  end

  def test_skips_service_without_expose_label
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new.call(m)

    assert_equal 1, m.resources.size
  end

  def test_skips_non_service_resources
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
    })

    Middleware::IngressForService.new.call(m)

    assert_equal 1, m.resources.size
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
