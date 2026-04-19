#!/usr/bin/env ruby
# frozen_string_literal: true

# Middleware-driven Manifest Example
#
# Demonstrates how middleware eliminates boilerplate. The middleware stack
# declared in MyApp automatically generates Services, Ingresses, HPAs,
# and injects resource limits, security contexts, and pod anti-affinity.
#
# The block below only declares the unique intent — the things only a
# human knows. Everything else is derived by middleware from labels.
#
# What middleware generates from each Deployment:
#   - Service           (from container ports + matchLabels)
#   - Ingress           (from app.kubernetes.io/expose label)
#   - HPA               (from app.kubernetes.io/autoscale label)
#   - Resource limits   (from app.kubernetes.io/size label)
#   - Security contexts (restricted profile, all pod-bearing resources)
#   - Pod anti-affinity (spread across nodes, all pod-bearing resources)
#   - Standard labels   (managed-by, merged into everything)
#
# Usage:
#   ruby examples/version2/demo.rb
#   ruby examples/version2/demo.rb > app.yaml

require "kube/cluster"
require "securerandom"
require_relative "my_app"

app = MyApp.new("example.com", size: :small) do |m|
  name    = "rails-app"
  ns      = "production"
  db_name = "postgresql"
  db_ns   = "database"

  labels    = m.app_labels(name: name, instance: name)
  db_labels = m.app_labels(name: db_name, instance: db_name, component: "primary")
  db_match  = m.match_labels(name: db_name, instance: db_name, component: "primary")

  # ── Rails tier ──────────────────────────────────────────────────
  #
  # One Namespace, one ConfigMap, one Deployment.
  # Middleware generates: Service, Ingress, HPA
  # Middleware injects:   resource limits, security context, anti-affinity, labels

  [
    Kube::Cluster["Namespace"].new {
      metadata.name   = ns
      metadata.labels = labels
    },

    Kube::Cluster["ConfigMap"].new {
      metadata.name      = "#{name}-config"
      metadata.namespace = ns
      metadata.labels    = labels
      self.data = {
        RAILS_ENV:    "production",
        DATABASE_URL: "postgres://#{db_name}-headless.#{db_ns}.svc.cluster.local:5432/app",
        LOG_LEVEL:    "info",
        WORKERS:      "4",
      }
    },

    RubyOnRails.new {
      metadata.name      = name
      metadata.namespace = ns
      metadata.labels    = labels.merge(
        "app.kubernetes.io/expose":    "app.example.com",
        "app.kubernetes.io/autoscale": "1-5",
      )
    },
  ]

  # ── Database tier ───────────────────────────────────────────────
  #
  # StatefulSet + headless Service + Secret + NetworkPolicy.
  # Middleware generates: Service (from container ports)
  # Middleware injects:   resource limits, security context, anti-affinity, labels

  pg_password = SecureRandom.alphanumeric(24)

  Postgresql.new {
  }

end

puts app.to_yaml
