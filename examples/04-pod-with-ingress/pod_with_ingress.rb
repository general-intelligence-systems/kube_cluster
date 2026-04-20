# frozen_string_literal: true

class PodWithIngress < Kube::Cluster::Manifest
  def initialize(name:, image:, port:, host:, &block)
    match_labels = { app: name }

    super(
      Kube::Cluster["Pod"].new {
        metadata.name   = name
        metadata.labels = match_labels

        spec.containers = [
          {
            name: name,
            image: image,
            imagePullPolicy: "Always",
            ports: [
              { name: "http", containerPort: port }
            ],
          }
        ]
      },

      Kube::Cluster["Service"].new {
        metadata.name = name

        spec.selector = match_labels
        spec.ports = [
          { port: port, targetPort: "http" }
        ]
      },

      Kube::Cluster["Ingress"].new {
        metadata.name = name

        spec.rules = [
          {
            host: host,
            http: {
              paths: [
                {
                  path: "/",
                  pathType: "Prefix",
                  backend: {
                    service: {
                      name: name,
                      port: { number: port },
                    },
                  },
                },
              ],
            },
          },
        ]
      },
    )

    instance_exec(&block) if block
  end
end
