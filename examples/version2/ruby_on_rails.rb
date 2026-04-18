class RubyOnRails < Kube::Schema["Deployment"]
  default do
    metadata.name      = name
    metadata.namespace = ns
    metadata.labels    = labels.merge(
      "app.kubernetes.io/expose":    "app.example.com",
      "app.kubernetes.io/autoscale": "1-5",
    )
    spec.replicas = 1
    spec.selector.matchLabels = m.match_labels(name: name, instance: name)
    spec.template.metadata.labels = labels
    spec.template.spec.containers = [
      {
        name:    name,
        image:   "ghcr.io/acme/rails-app:2.0",
        ports:   [{ name: "http", containerPort: 3000, protocol: "TCP" }],
        envFrom: [{ configMapRef: { name: "#{name}-config" } }],
        livenessProbe: {
          httpGet: { path: "/healthz", port: "http" },
          initialDelaySeconds: 15,
          periodSeconds: 10,
        },
        readinessProbe: {
          httpGet: { path: "/readyz", port: "http" },
          initialDelaySeconds: 5,
          periodSeconds: 5,
        },
      },
    ]
  end
end
