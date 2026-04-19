class Ingress < Kube::Schema["Ingress"]
  def initialize(namespace:)
    build {
      metadata.name = namespace
      metadata.annotations = {
        "cert-manager.io/cluster-issuer": "letsencrypt-prod",
        "nginx.ingress.kubernetes.io/ssl-redirect": "true",
      }

      spec.ingressClassName = "nginx"
      spec.tls = [
        {
          hosts: ["app.example.com"],
          secretName: "#{namespace}-tls",
        },
      ]
      spec.rules = [
        {
          host: "app.example.com",
          http: {
            paths: [
              {
                path: "/",
                pathType: "Prefix",
                backend: {
                  service: {
                    name: FULLNAME,
                    port: { name: "http" },
                  },
                },
              },
            ],
          },
        },
      ]
    }
  end
end
