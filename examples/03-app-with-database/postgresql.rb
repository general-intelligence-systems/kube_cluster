class Postgresql < Kube::Cluster::Manifest

  def initialize(namespace: nil)
    super
    @namespace = namespace

    self << Namespace.new
    self << StatefulSet.new
    self << Service.new
    self << Secret.new
  end

  class StatefulSet < Kube::Cluster["StatefulSet"]
    metadata.name      = db_name
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    spec.serviceName = "#{db_name}-headless"
    spec.replicas    = 1
    spec.selector.matchLabels = db_match
    spec.template.metadata.labels = db_labels
    spec.template.spec.containers = [
      {
        name:  "postgres",
        image: "docker.io/postgres:16.4-alpine",
        ports: [{ name: "tcp-postgresql", containerPort: 5432 }],
        env: [
          { name: "POSTGRES_PASSWORD", valueFrom: { secretKeyRef: { name: db_name, key: "postgres-password" } } },
          { name: "PGDATA", value: "/var/lib/postgresql/data/pgdata" },
        ],
        volumeMounts: [{ name: "data", mountPath: "/var/lib/postgresql/data" }],
        livenessProbe: {
          exec: { command: ["pg_isready", "-U", "postgres"] },
          initialDelaySeconds: 30,
          periodSeconds: 10,
          timeoutSeconds: 5,
          failureThreshold: 6,
        },
        readinessProbe: {
          exec: { command: ["pg_isready", "-U", "postgres"] },
          initialDelaySeconds: 5,
          periodSeconds: 10,
          timeoutSeconds: 5,
          failureThreshold: 6,
        },
      },
    ]
    spec.volumeClaimTemplates = [
      {
        metadata: { name: "data" },
        spec: {
          accessModes: ["ReadWriteOnce"],
          resources: { requests: { storage: "10Gi" } },
        },
      },
    ]
  end

  class Namespace < Kube::Cluster["Namespace"]
    metadata.name   = db_ns
    metadata.labels = db_labels.reject { |k, _| k == :"app.kubernetes.io/component" }
  end

  class Secret < Kube::Cluster["Secret"]
    metadata.name      = db_name
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    self.type = "Opaque"
    self.data = { "postgres-password": m.base64(pg_password) }
  end

  # Headless service for StatefulSet DNS — explicit because the
  # middleware-generated Service is a regular ClusterIP service.
  class Service < Kube::Cluster["Service"]
    metadata.name      = "#{db_name}-headless"
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    spec.clusterIP = "None"
    spec.selector  = db_match
    spec.ports     = [{ name: "tcp-postgresql", port: 5432, targetPort: "tcp-postgresql" }]
  end
end
