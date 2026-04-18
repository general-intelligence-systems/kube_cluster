#!/usr/bin/env ruby
# frozen_string_literal: true

# Database (PostgreSQL) Example
#
# Demonstrates the Ruby equivalents of Bitnami common chart patterns:
#   - Secret lifecycle management (_secrets.tpl)
#   - StorageClass resolution (_storage.tpl)
#   - StatefulSet with persistent volumes
#   - Headless service for stable DNS
#   - NetworkPolicy for database isolation
#   - Standard labels and naming (_labels.tpl, _names.tpl)
#   - Resource presets (_resources.tpl)
#
# Usage:
#   ruby examples/database/manifest.rb
#   ruby examples/database/manifest.rb > database.yaml

require "kube/schema"
require "securerandom"

# ── Naming ────────────────────────────────────────────────────────────────────

APP_NAME      = "postgresql"
RELEASE_NAME  = "my-release"
NAMESPACE     = "database"
FULLNAME      = "#{RELEASE_NAME}-#{APP_NAME}"[0, 63].chomp("-")

# ── Labels ────────────────────────────────────────────────────────────────────

STANDARD_LABELS = {
  "app.kubernetes.io/name": APP_NAME,
  "app.kubernetes.io/instance": RELEASE_NAME,
  "app.kubernetes.io/version": "16.4.0",
  "app.kubernetes.io/component": "primary",
  "app.kubernetes.io/managed-by": "kube_cluster",
}

MATCH_LABELS = STANDARD_LABELS.slice(
  :"app.kubernetes.io/name",
  :"app.kubernetes.io/instance",
  :"app.kubernetes.io/component",
)

# ── Secrets (from _secrets.tpl) ───────────────────────────────────────────────
# Bitnami's secrets.passwords.manage generates random passwords, reuses existing
# ones on upgrade, and base64 encodes them. In Ruby we do this directly.

POSTGRES_PASSWORD = SecureRandom.alphanumeric(24)
REPLICATION_PASSWORD = SecureRandom.alphanumeric(24)

def base64(str)
  [str].pack("m0")
end

# ── Storage (from _storage.tpl) ───────────────────────────────────────────────
# Bitnami resolves storage class from global > persistence > default.
# The "-" convention means explicitly use the default storage class (empty string).

STORAGE_CLASS = "standard" # set to "-" for default, or nil to omit
STORAGE_SIZE  = "10Gi"

# ── Resource presets ──────────────────────────────────────────────────────────

RESOURCES = {
  requests: { cpu: "500m",  memory: "512Mi"  },
  limits:   { cpu: "750m",  memory: "768Mi"  },
}

# ── Build manifests ───────────────────────────────────────────────────────────

manifest = Kube::Schema::Manifest.new

# -- Namespace --

manifest << Kube::Schema["Namespace"].new {
  metadata.name   = NAMESPACE
  metadata.labels = STANDARD_LABELS.reject { |k, _| k == :"app.kubernetes.io/component" }
}

# -- Secret --
# Pattern from _secrets.tpl: base64-encoded credentials, separate keys for
# each password, supports existing secret reuse on upgrade.

manifest << Kube::Schema["Secret"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS
  self.type = "Opaque"
  self.data = {
    "postgres-password":    base64(POSTGRES_PASSWORD),
    "replication-password": base64(REPLICATION_PASSWORD),
  }
}

# -- Headless Service (for StatefulSet stable DNS) --

manifest << Kube::Schema["Service"].new {
  metadata.name      = "#{FULLNAME}-headless"
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.clusterIP = "None"
  spec.selector  = MATCH_LABELS
  spec.ports = [
    { name: "tcp-postgresql", port: 5432, targetPort: "tcp-postgresql" },
  ]
}

# -- Primary Service (for client connections) --

manifest << Kube::Schema["Service"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.selector = MATCH_LABELS
  spec.ports = [
    { name: "tcp-postgresql", port: 5432, targetPort: "tcp-postgresql" },
  ]
}

# -- StatefulSet --
# Uses storage class resolution pattern, secret references, resource presets,
# pod anti-affinity for spreading replicas.

manifest << Kube::Schema["StatefulSet"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.serviceName = "#{FULLNAME}-headless"
  spec.replicas    = 1
  spec.selector.matchLabels = MATCH_LABELS

  spec.template.metadata.labels = STANDARD_LABELS
  spec.template.spec.containers = [
    {
      name:  APP_NAME,
      image: "docker.io/postgres:16.4-alpine",
      ports: [
        { name: "tcp-postgresql", containerPort: 5432 },
      ],
      resources: RESOURCES,
      env: [
        { name: "POSTGRES_PASSWORD", valueFrom: { secretKeyRef: { name: FULLNAME, key: "postgres-password" } } },
        { name: "PGDATA", value: "/var/lib/postgresql/data/pgdata" },
      ],
      volumeMounts: [
        { name: "data", mountPath: "/var/lib/postgresql/data" },
      ],
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

  # Pod anti-affinity: hard anti-affinity to guarantee one pod per node
  # (from _affinities.tpl: common.affinities.pods.hard)
  spec.template.spec.affinity = {
    podAntiAffinity: {
      requiredDuringSchedulingIgnoredDuringExecution: [
        {
          labelSelector: { matchLabels: MATCH_LABELS },
          topologyKey: "kubernetes.io/hostname",
        },
      ],
    },
  }

  # Storage class resolution (from _storage.tpl)
  storage_class = STORAGE_CLASS == "-" ? "" : STORAGE_CLASS

  spec.volumeClaimTemplates = [
    {
      metadata: { name: "data" },
      spec: {
        accessModes: ["ReadWriteOnce"],
        storageClassName: storage_class,
        resources: { requests: { storage: STORAGE_SIZE } },
      },
    },
  ]
}

# -- NetworkPolicy --
# Isolate the database: only allow ingress from pods with the app label,
# deny everything else. This is a common production hardening pattern.

manifest << Kube::Schema["NetworkPolicy"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.podSelector = { matchLabels: MATCH_LABELS }
  spec.policyTypes = ["Ingress", "Egress"]
  spec.ingress = [
    {
      from: [
        {
          podSelector: {
            matchLabels: { "app.kubernetes.io/name": "web-app" },
          },
        },
      ],
      ports: [
        { protocol: "TCP", port: "5432" },
      ],
    },
  ]
  # Allow DNS egress + nothing else
  spec.egress = [
    {
      to: [
        { namespaceSelector: {} },
      ],
      ports: [
        { protocol: "UDP", port: "53" },
        { protocol: "TCP", port: "53" },
      ],
    },
  ]
}

# ── Render ────────────────────────────────────────────────────────────────────

puts manifest.to_yaml
