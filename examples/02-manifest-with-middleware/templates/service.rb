class Service < Kube::Cluster["Service"]
  def initialize(namespace:)
    super {
      metadata.name = namespace

      spec.selector = MATCH_LABELS
      spec.ports = [
        { name: "http", port: 80, targetPort: "http", protocol: "TCP" },
      ]
    }
  end
end
