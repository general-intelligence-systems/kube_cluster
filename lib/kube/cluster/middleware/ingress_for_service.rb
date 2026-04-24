# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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

        def call(manifest)
          generated = []
          issuer        = @opts.fetch(:issuer, "letsencrypt-prod")
          ingress_class = @opts.fetch(:ingress_class, "nginx")

          manifest.resources.each do |resource|
            filter(resource) do
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
          end

          manifest.resources.concat(generated)
        end
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  it "generates_ingress_from_service_with_expose_label" do
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
      spec.selector = { app: "web" }
      spec.ports = [{ name: "http", port: 80, targetPort: "http" }]
    })

    Middleware::IngressForService.new.call(m)

    service, ingress = m.resources
    ih = ingress.to_h
    rule = ih.dig(:spec, :rules, 0)

    rule.dig(:http, :paths, 0, :backend, :service, :port, :name).should == "http"
  end

  it "custom_issuer_and_ingress_class" do
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

    ingress.dig(:metadata, :annotations, :"cert-manager.io/cluster-issuer").should == "letsencrypt-staging"
  end

  it "expose_true_uses_name_as_hostname" do
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "api"
      metadata.labels = { "app.kubernetes.io/expose": "true" }
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new.call(m)
    ingress = m.resources.last.to_h

    ingress.dig(:spec, :tls, 0, :hosts).should == ["api.local"]
  end

  it "strips_expose_label_from_ingress" do
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

    ingress_labels[:"app.kubernetes.io/expose"].should.be.nil
  end

  it "skips_service_without_expose_label" do
    m = manifest(Kube::Cluster["Service"].new {
      metadata.name = "web"
      spec.ports = [{ name: "http", port: 80 }]
    })

    Middleware::IngressForService.new.call(m)

    m.resources.size.should == 1
  end

  it "skips_non_service_resources" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/expose": "app.example.com" }
    })

    Middleware::IngressForService.new.call(m)

    m.resources.size.should == 1
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
