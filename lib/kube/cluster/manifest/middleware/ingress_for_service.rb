# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
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

          def call(resource)
            return resource unless kind(resource) == "Service"

            host = label(resource, LABEL)
            return resource unless host

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

            ingress = Kube::Schema["Ingress"].new {
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

            [resource, ingress]
          end
        end
      end
    end
  end
end
