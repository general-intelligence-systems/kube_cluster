class Deployment < Kube::Cluster["Deployment"]
  def initialize(namespace:)
    build {
      metadata.name = namespace

      spec.replicas = 3
      spec.selector.matchLabels = MATCH_LABELS

      spec.template.metadata.labels = STANDARD_LABELS
      spec.template.metadata.annotations = {
        # Checksum pattern from _utils.tpl -- triggers rolling restart on config change
        "checksum/config": "{{ sha256sum of configmap data }}",
      }

      spec.template.spec.containers = [
        {
          name:  APP_NAME,
          image: IMAGE,
          ports: [{ name: "http", containerPort: 3000, protocol: "TCP" }],
          resources: RESOURCES,
          env: [
            { name: "PORT", value: "3000" },
          ],
          envFrom: [
            { configMapRef: { name: "#{FULLNAME}-config" } },
          ],
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

      # Pod anti-affinity (from _affinities.tpl)
      # Soft anti-affinity: prefer spreading pods across nodes but don't enforce it
      spec.template.spec.affinity = {
        podAntiAffinity: {
          preferredDuringSchedulingIgnoredDuringExecution: [
            {
              weight: 1,
              podAffinityTerm: {
                labelSelector: {
                  matchLabels: MATCH_LABELS,
                },
                topologyKey: "kubernetes.io/hostname",
              },
            },
          ],
        },
      }
    }
  end
end
