# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

module Kube
  module Cluster
    class Middleware
      # Generates an Ingress for every Service whose source resource
      # carries the +app.kubernetes.io/expose+ label.
      #
      # The label value is the hostname:
      #
      #   metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
      #
      # Set to +"true"+ to use the resource name as a hostname placeholder
      # (useful when a later middleware or the manifest class resolves it).
      #
      # Options:
      #   issuer:          — cert-manager ClusterIssuer name (default: "letsencrypt-prod")
      #   ingress_class:   — IngressClassName (default: "nginx")
      #
      #   stack do
      #     use Middleware::IngressForService
      #     use Middleware::IngressForService, issuer: "letsencrypt-staging"
      #   end
      #
      class IngressForService < Middleware
        LABEL = :"app.kubernetes.io/expose"

        def initialize(issuer: "letsencrypt-prod", ingress_class: "nginx")
          @issuer = issuer
          @ingress_class = ingress_class
        end

        def call(manifest)
          generated = []

          manifest.resources.each do |resource|
            next unless resource.kind == "Service"

            host = resource.label(LABEL)
            next unless host

            h = resource.to_h
            name      = h.dig(:metadata, :name)
            namespace = h.dig(:metadata, :namespace)
            labels    = h.dig(:metadata, :labels) || {}

            # Find the first port on the service
            port_name = Array(h.dig(:spec, :ports)).first&.dig(:name) || "http"

            # Use resource name as hostname fallback if label is just "true"
            host = "#{name}.local" if host == "true"

            # Capture ivars as locals — the block runs via instance_exec
            # on a BlackHoleStruct, so @ivars would resolve on the BHS.
            issuer        = @issuer
            ingress_class = @ingress_class

            generated << Kube::Cluster["Ingress"].new {
              metadata.name      = name
              metadata.namespace = namespace if namespace
              metadata.labels    = labels.reject { |k, _| k == LABEL }
              metadata.annotations = {
                "cert-manager.io/cluster-issuer":           issuer,
                "nginx.ingress.kubernetes.io/ssl-redirect": "true",
              }

              spec.ingressClassName = ingress_class
              spec.tls = [
                { hosts: [host], secretName: "#{name}-tls" },
              ]
              spec.rules = [
                {
                  host: host,
                  http: {
                    paths: [{
                      path:     "/",
                      pathType: "Prefix",
                      backend:  { service: { name: name, port: { name: port_name } } },
                    }],
                  },
                },
              ]
            }
          end

          manifest.resources.concat(generated)
        end
      end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

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
end
