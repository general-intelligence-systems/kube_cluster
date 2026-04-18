#!/usr/bin/env ruby
# frozen_string_literal: true

# Microservices Platform Example
#
# Demonstrates the Ruby equivalents of Bitnami common chart patterns:
#   - Multi-component naming with component labels (_names.tpl, _labels.tpl)
#   - RBAC with API version helpers (_capabilities.tpl)
#   - SecurityContext with OpenShift compatibility (_compatibility.tpl)
#   - NetworkPolicy per-service isolation
#   - Node affinity for zone-aware scheduling (_affinities.tpl)
#   - Resource presets per service size (_resources.tpl)
#   - Image pull secrets aggregation (_images.tpl)
#
# Usage:
#   ruby examples/microservices/manifest.rb
#   ruby examples/microservices/manifest.rb > microservices.yaml

require "kube/schema"

# ── Naming ────────────────────────────────────────────────────────────────────

RELEASE_NAME = "platform"
NAMESPACE    = "microservices"

# ── Component definitions ─────────────────────────────────────────────────────
# Each service gets its own labels, image, resources, and port config.
# This mirrors how Bitnami charts compose per-component config from a shared
# set of helpers.

COMPONENTS = {
  api: {
    image:    "ghcr.io/acme/api-gateway:2.1.0",
    port:     8080,
    replicas: 3,
    resources: { requests: { cpu: "500m", memory: "512Mi" }, limits: { cpu: "750m", memory: "768Mi" } },
  },
  worker: {
    image:    "ghcr.io/acme/worker:1.8.4",
    port:     9090,
    replicas: 2,
    resources: { requests: { cpu: "250m", memory: "256Mi" }, limits: { cpu: "375m", memory: "384Mi" } },
  },
  scheduler: {
    image:    "ghcr.io/acme/scheduler:1.3.0",
    port:     9091,
    replicas: 1,
    resources: { requests: { cpu: "100m", memory: "128Mi" }, limits: { cpu: "150m", memory: "192Mi" } },
  },
}

# ── Label helpers (from _labels.tpl) ──────────────────────────────────────────
# Bitnami generates standard + match labels per component.

def standard_labels(component)
  {
    "app.kubernetes.io/name":      "platform",
    "app.kubernetes.io/instance":  RELEASE_NAME,
    "app.kubernetes.io/version":   "1.0.0",
    "app.kubernetes.io/component": component.to_s,
    "app.kubernetes.io/managed-by": "kube_cluster",
  }
end

def match_labels(component)
  standard_labels(component).slice(
    :"app.kubernetes.io/name",
    :"app.kubernetes.io/instance",
    :"app.kubernetes.io/component",
  )
end

# ── Naming helper (from _names.tpl) ──────────────────────────────────────────
# Bitnami: release-name-component, truncated to 63 chars

def fullname(component)
  "#{RELEASE_NAME}-#{component}"[0, 63].chomp("-")
end

# ── SecurityContext (from _compatibility.tpl) ──────────────────────────────────
# Bitnami strips runAsUser/fsGroup on OpenShift. Here we define a standard
# non-root security context that works everywhere.

CONTAINER_SECURITY_CONTEXT = {
  runAsNonRoot:             true,
  runAsUser:                1000,
  allowPrivilegeEscalation: false,
  readOnlyRootFilesystem:   true,
  capabilities:             { drop: ["ALL"] },
}

POD_SECURITY_CONTEXT = {
  fsGroup:    1000,
  runAsUser:  1000,
  runAsGroup: 1000,
}

# ── Image pull secrets (from _images.tpl) ─────────────────────────────────────
# Bitnami aggregates pull secrets from global + per-image config.

IMAGE_PULL_SECRETS = [
  { name: "ghcr-credentials" },
]

# ── Build manifests ───────────────────────────────────────────────────────────

manifest = Kube::Schema::Manifest.new

# -- Namespace --

manifest << Kube::Schema["Namespace"].new {
  metadata.name = NAMESPACE
  metadata.labels = {
    "app.kubernetes.io/name":      "platform",
    "app.kubernetes.io/instance":  RELEASE_NAME,
    "app.kubernetes.io/managed-by": "kube_cluster",
  }
}

# -- ServiceAccount + RBAC (from _capabilities.tpl: rbac.authorization.k8s.io/v1) --
# Bitnami uses capabilities helpers to pick the right apiVersion for RBAC.
# With modern k8s it's always rbac.authorization.k8s.io/v1.

sa_name = "#{RELEASE_NAME}-sa"

manifest << Kube::Schema["ServiceAccount"].new {
  metadata.name      = sa_name
  metadata.namespace  = NAMESPACE
  metadata.labels     = standard_labels(:platform)
  self.automountServiceAccountToken = false
}

manifest << Kube::Schema["Role"].new {
  metadata.name      = "#{RELEASE_NAME}-role"
  metadata.namespace  = NAMESPACE
  metadata.labels     = standard_labels(:platform)

  self.rules = [
    {
      apiGroups: [""],
      resources: ["configmaps", "secrets"],
      verbs:     ["get", "list", "watch"],
    },
    {
      apiGroups: [""],
      resources: ["pods"],
      verbs:     ["get", "list"],
    },
  ]
}

manifest << Kube::Schema["RoleBinding"].new {
  metadata.name      = "#{RELEASE_NAME}-rolebinding"
  metadata.namespace  = NAMESPACE
  metadata.labels     = standard_labels(:platform)

  self.roleRef = {
    apiGroup: "rbac.authorization.k8s.io",
    kind:     "Role",
    name:     "#{RELEASE_NAME}-role",
  }
  self.subjects = [
    { kind: "ServiceAccount", name: sa_name, namespace: NAMESPACE },
  ]
}

# -- Per-component Deployment + Service + NetworkPolicy --

COMPONENTS.each do |component, config|
  name = fullname(component)

  # Deployment
  manifest << Kube::Schema["Deployment"].new {
    metadata.name      = name
    metadata.namespace  = NAMESPACE
    metadata.labels     = standard_labels(component)

    spec.replicas = config[:replicas]
    spec.selector.matchLabels = match_labels(component)

    spec.template.metadata.labels = standard_labels(component)
    spec.template.spec.serviceAccountName = sa_name
    spec.template.spec.automountServiceAccountToken = false
    spec.template.spec.imagePullSecrets = IMAGE_PULL_SECRETS
    spec.template.spec.securityContext  = POD_SECURITY_CONTEXT

    spec.template.spec.containers = [
      {
        name:            component.to_s,
        image:           config[:image],
        ports:           [{ name: "http", containerPort: config[:port], protocol: "TCP" }],
        resources:       config[:resources],
        securityContext: CONTAINER_SECURITY_CONTEXT,
        livenessProbe: {
          httpGet: { path: "/healthz", port: "http" },
          initialDelaySeconds: 10,
          periodSeconds: 10,
        },
        readinessProbe: {
          httpGet: { path: "/readyz", port: "http" },
          initialDelaySeconds: 5,
          periodSeconds: 5,
        },
      },
    ]

    # Node affinity (from _affinities.tpl: common.affinities.nodes.soft)
    # Prefer scheduling in specific availability zones
    spec.template.spec.affinity = {
      nodeAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [
          {
            weight: 1,
            preference: {
              matchExpressions: [
                { key: "topology.kubernetes.io/zone", operator: "In", values: ["us-east-1a", "us-east-1b"] },
              ],
            },
          },
        ],
      },
      # Pod anti-affinity (from _affinities.tpl: common.affinities.pods.soft)
      # Spread component pods across nodes
      podAntiAffinity: {
        preferredDuringSchedulingIgnoredDuringExecution: [
          {
            weight: 1,
            podAffinityTerm: {
              labelSelector: { matchLabels: match_labels(component) },
              topologyKey: "kubernetes.io/hostname",
            },
          },
        ],
      },
    }
  }

  # Service
  manifest << Kube::Schema["Service"].new {
    metadata.name      = name
    metadata.namespace  = NAMESPACE
    metadata.labels     = standard_labels(component)

    spec.selector = match_labels(component)
    spec.ports = [
      { name: "http", port: config[:port], targetPort: "http", protocol: "TCP" },
    ]
  }

  # NetworkPolicy -- per-component isolation
  # Each service only accepts traffic from the api gateway, and can egress to
  # DNS + other services in the namespace.
  manifest << Kube::Schema["NetworkPolicy"].new {
    metadata.name      = "#{name}-netpol"
    metadata.namespace  = NAMESPACE
    metadata.labels     = standard_labels(component)

    spec.podSelector = { matchLabels: match_labels(component) }
    spec.policyTypes = ["Ingress", "Egress"]

    # Ingress: allow from api component (or from ingress controller for api itself)
    ingress_from = if component == :api
      [{ namespaceSelector: {}, podSelector: { matchLabels: { "app.kubernetes.io/name": "ingress-nginx" } } }]
    else
      [{ podSelector: { matchLabels: match_labels(:api) } }]
    end

    spec.ingress = [
      { from: ingress_from, ports: [{ protocol: "TCP", port: config[:port].to_s }] },
    ]

    # Egress: DNS + intra-namespace
    spec.egress = [
      # DNS
      { to: [{ namespaceSelector: {} }], ports: [{ protocol: "UDP", port: "53" }, { protocol: "TCP", port: "53" }] },
      # Same namespace
      { to: [{ podSelector: {} }] },
    ]
  }
end

# ── Render ────────────────────────────────────────────────────────────────────

puts manifest.to_yaml
