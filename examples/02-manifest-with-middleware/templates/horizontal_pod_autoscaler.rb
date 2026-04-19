class HorizontalPodAutoscaler < Kube::Cluster["HorizontalPodAutoscaler"]
  def initialize(namespace:)
    super {
      metadata.name = namespace

      spec.scaleTargetRef.apiVersion = "apps/v1"
      spec.scaleTargetRef.kind = "Deployment"
      spec.scaleTargetRef.name = namespace

      spec.minReplicas = 3
      spec.maxReplicas = 10
      spec.metrics = [
        {
          type: "Resource",
          resource: {
            name: "cpu",
            target: { type: "Utilization", averageUtilization: 75 },
          },
        },
        {
          type: "Resource",
          resource: {
            name: "memory",
            target: { type: "Utilization", averageUtilization: 80 },
          },
        },
      ]
    }
  end
end
