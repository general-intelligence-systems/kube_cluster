class Service < Kube::Schema["Service"]
  def initialize(namespace:)
    build {
      metadata.name = namespace

      spec.selector = MATCH_LABELS
      spec.ports = [
        { name: "http", port: 80, targetPort: "http", protocol: "TCP" },
      ]
    }
  end
end
