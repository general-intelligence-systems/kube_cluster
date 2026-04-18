#!/usr/bin/env ruby
# frozen_string_literal: true

# Web Application Example
#
# Demonstrates the Ruby equivalents of Bitnami common chart patterns:
#   - Standard Kubernetes labels (_labels.tpl)
#   - Naming conventions with 63-char DNS truncation (_names.tpl)
#   - Image construction with registry/repo/tag (_images.tpl)
#   - Resource presets / t-shirt sizing (_resources.tpl)
#   - Pod anti-affinity for HA scheduling (_affinities.tpl)
#   - Ingress with cert-manager annotations (_ingress.tpl)
#   - HorizontalPodAutoscaler (_capabilities.tpl)
#
# Usage:
#   ruby examples/web-app/manifest.rb
#   ruby examples/web-app/manifest.rb > web-app.yaml

require "kube/schema"

# ── Naming (from _names.tpl) ──────────────────────────────────────────────────
# Bitnami truncates names to 63 chars for DNS compliance.
# In Ruby we can just do this inline.

APP_NAME      = "web-app"
RELEASE_NAME  = "my-release"
NAMESPACE     = "production"
FULLNAME      = "#{RELEASE_NAME}-#{APP_NAME}"[0, 63].chomp("-")
CHART_VERSION = "1.0.0"

# ── Labels (from _labels.tpl) ─────────────────────────────────────────────────
# Standard Kubernetes recommended labels. The Bitnami chart splits these into
# "standard" (all labels) and "matchLabels" (immutable selector subset).

STANDARD_LABELS = {
  "app.kubernetes.io/name": APP_NAME,
  "app.kubernetes.io/instance": RELEASE_NAME,
  "app.kubernetes.io/version": CHART_VERSION,
  "app.kubernetes.io/managed-by": "kube_cluster",
}

MATCH_LABELS = STANDARD_LABELS.slice(
  :"app.kubernetes.io/name",
  :"app.kubernetes.io/instance",
)

# ── Images (from _images.tpl) ─────────────────────────────────────────────────
# Bitnami constructs images from registry/repository/tag with a global override.
# In Ruby we can just build the string.

REGISTRY   = "docker.io"
REPOSITORY = "nginx"
TAG        = "1.27.3-alpine"
IMAGE      = "#{REGISTRY}/#{REPOSITORY}:#{TAG}"

# ── Resource presets (from _resources.tpl) ─────────────────────────────────────
# Bitnami defines t-shirt sizes: nano, micro, small, medium, large, xlarge, 2xlarge.
# Limits are ~1.5x requests. Here we use the "small" preset.

RESOURCE_PRESETS = {
  nano:    { requests: { cpu: "100m",  memory: "128Mi"  }, limits: { cpu: "150m",  memory: "192Mi"  } },
  micro:   { requests: { cpu: "250m",  memory: "256Mi"  }, limits: { cpu: "375m",  memory: "384Mi"  } },
  small:   { requests: { cpu: "500m",  memory: "512Mi"  }, limits: { cpu: "750m",  memory: "768Mi"  } },
  medium:  { requests: { cpu: "500m",  memory: "1024Mi" }, limits: { cpu: "750m",  memory: "1536Mi" } },
  large:   { requests: { cpu: "1.0",   memory: "2048Mi" }, limits: { cpu: "1.5",   memory: "3072Mi" } },
  xlarge:  { requests: { cpu: "1.0",   memory: "3072Mi" }, limits: { cpu: "3.0",   memory: "6144Mi" } },
  :"2xlarge" => { requests: { cpu: "1.0", memory: "3072Mi" }, limits: { cpu: "6.0", memory: "12288Mi" } },
}

RESOURCES = RESOURCE_PRESETS[:small]

# ── Build manifests ───────────────────────────────────────────────────────────

manifest = Kube::Schema::Manifest.new

# -- Namespace --

manifest << Kube::Schema["Namespace"].new {
  metadata.name = NAMESPACE
  metadata.labels = STANDARD_LABELS
}

# -- ConfigMap --

manifest << Kube::Schema["ConfigMap"].new {
  metadata.name      = "#{FULLNAME}-config"
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS
  self.data = {
    RAILS_ENV:     "production",
    LOG_LEVEL:     "info",
    WORKERS:       "4",
    PORT:          "3000",
  }
}

# -- Deployment --
# Uses: labels, match_labels, image construction, resource presets, pod anti-affinity

manifest << Kube::Schema["Deployment"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

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

# -- Service --

manifest << Kube::Schema["Service"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.selector = MATCH_LABELS
  spec.ports = [
    { name: "http", port: 80, targetPort: "http", protocol: "TCP" },
  ]
}

# -- Ingress (from _ingress.tpl) --
# Uses cert-manager annotations for TLS, standard backend construction

manifest << Kube::Schema["Ingress"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS
  metadata.annotations = {
    "cert-manager.io/cluster-issuer": "letsencrypt-prod",
    "nginx.ingress.kubernetes.io/ssl-redirect": "true",
  }

  spec.ingressClassName = "nginx"
  spec.tls = [
    {
      hosts: ["app.example.com"],
      secretName: "#{FULLNAME}-tls",
    },
  ]
  spec.rules = [
    {
      host: "app.example.com",
      http: {
        paths: [
          {
            path: "/",
            pathType: "Prefix",
            backend: {
              service: {
                name: FULLNAME,
                port: { name: "http" },
              },
            },
          },
        ],
      },
    },
  ]
}

# -- HorizontalPodAutoscaler (from _capabilities.tpl: autoscaling/v2) --

manifest << Kube::Schema["HorizontalPodAutoscaler"].new {
  metadata.name      = FULLNAME
  metadata.namespace  = NAMESPACE
  metadata.labels     = STANDARD_LABELS

  spec.scaleTargetRef = {
    apiVersion: "apps/v1",
    kind:       "Deployment",
    name:       FULLNAME,
  }
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

# ── Render ────────────────────────────────────────────────────────────────────

puts manifest.to_yaml
