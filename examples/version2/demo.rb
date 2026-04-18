#!/usr/bin/env ruby
# frozen_string_literal: true

require "kube/schema"
require "securerandom"
require_relative "my_app"

include App::Helpers

app = App::MyApp.new("example.com", size: :small) do |m|
  name     = "rails-app"
  ns       = "production"
  db_name  = "postgresql"
  db_ns    = "database"

  labels    = m.standard_labels(name: name, instance: name).merge(m.app_labels)
  match     = m.match_labels(name: name, instance: name)
  db_labels = m.standard_labels(name: db_name, instance: db_name, component: "primary").merge(m.app_labels)
  db_match  = m.match_labels(name: db_name, instance: db_name, component: "primary")

  # ── Rails tier ──────────────────────────────────────────────────

  m << Kube::Schema["Namespace"].new {
    metadata.name   = ns
    metadata.labels = labels
  }

  m << Kube::Schema["ConfigMap"].new {
    metadata.name      = "#{name}-config"
    metadata.namespace = ns
    metadata.labels    = labels
    self.data = {
      RAILS_ENV:    "production",
      DATABASE_URL: "postgres://#{db_name}-headless.#{db_ns}.svc.cluster.local:5432/app",
      LOG_LEVEL:    "info",
      WORKERS:      "4",
    }
  }

  m << Kube::Schema["Deployment"].new {
    metadata.name      = name
    metadata.namespace = ns
    metadata.labels    = labels
    spec.replicas      = 1
    spec.selector.matchLabels = match
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
  }

  m << Kube::Schema["Service"].new {
    metadata.name      = name
    metadata.namespace = ns
    metadata.labels    = labels
    spec.selector = match
    spec.ports    = [{ name: "http", port: 80, targetPort: "http", protocol: "TCP" }]
  }

  m << Kube::Schema["Ingress"].new {
    metadata.name      = name
    metadata.namespace = ns
    metadata.labels    = labels
    metadata.annotations = {
      "cert-manager.io/cluster-issuer":           "letsencrypt-prod",
      "nginx.ingress.kubernetes.io/ssl-redirect": "true",
    }
    spec.ingressClassName = "nginx"
    spec.tls = [
      { hosts: [m.rails_domain], secretName: "#{name}-tls" },
    ]
    spec.rules = [
      {
        host: m.rails_domain,
        http: {
          paths: [{
            path: "/",
            pathType: "Prefix",
            backend: { service: { name: name, port: { name: "http" } } },
          }],
        },
      },
    ]
  }

  m << Kube::Schema["HorizontalPodAutoscaler"].new {
    metadata.name      = name
    metadata.namespace = ns
    metadata.labels    = labels
    spec.scaleTargetRef = { apiVersion: "apps/v1", kind: "Deployment", name: name }
    spec.minReplicas = 1
    spec.maxReplicas = 5
    spec.metrics = [
      { type: "Resource", resource: { name: "cpu",    target: { type: "Utilization", averageUtilization: 75 } } },
      { type: "Resource", resource: { name: "memory", target: { type: "Utilization", averageUtilization: 80 } } },
    ]
  }

  # ── Database tier ───────────────────────────────────────────────

  pg_password = SecureRandom.alphanumeric(24)

  m << Kube::Schema["Namespace"].new {
    metadata.name   = db_ns
    metadata.labels = db_labels.reject { |k, _| k == :"app.kubernetes.io/component" }
  }

  m << Kube::Schema["Secret"].new {
    metadata.name      = db_name
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    self.type = "Opaque"
    self.data = { "postgres-password": m.base64(pg_password) }
  }

  m << Kube::Schema["Service"].new {
    metadata.name      = "#{db_name}-headless"
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    spec.clusterIP = "None"
    spec.selector  = db_match
    spec.ports     = [{ name: "tcp-postgresql", port: 5432, targetPort: "tcp-postgresql" }]
  }

  m << Kube::Schema["Service"].new {
    metadata.name      = db_name
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    spec.selector = db_match
    spec.ports    = [{ name: "tcp-postgresql", port: 5432, targetPort: "tcp-postgresql" }]
  }

  m << Kube::Schema["StatefulSet"].new {
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
  }

  m << Kube::Schema["NetworkPolicy"].new {
    metadata.name      = db_name
    metadata.namespace = db_ns
    metadata.labels    = db_labels
    spec.podSelector = { matchLabels: db_match }
    spec.policyTypes = ["Ingress", "Egress"]
    spec.ingress = [
      {
        from:  [{ podSelector: { matchLabels: { "app.kubernetes.io/name": name } }, namespaceSelector: { matchLabels: { "app.kubernetes.io/name": name } } }],
        ports: [{ protocol: "TCP", port: "5432" }],
      },
    ]
    spec.egress = [
      { to: [{ namespaceSelector: {} }], ports: [{ protocol: "UDP", port: "53" }, { protocol: "TCP", port: "53" }] },
    ]
  }
end

puts app.to_yaml
