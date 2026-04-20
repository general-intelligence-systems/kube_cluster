require "bundler/setup"
require "kube/cluster"

require_relative "resources/nginx"

# ── Nginx Deployment + cert-manager ───────────────────────────────────
#
# Deploys an nginx Deployment (config via ConfigMap) with automatic TLS
# via cert-manager and Let's Encrypt. Uses k3s's built-in Traefik ingress.

# ── 1. cert-manager (Helm) ───────────────────────────────────────────

certmanager_repo = Kube::Helm::Repo.new(
  "jetstack",
  url: "https://charts.jetstack.io",
)
certmanager_repo.add

certmanager_chart = certmanager_repo.chart("cert-manager", version: "1.17.2")

certmanager_chart.crds.each do |crd|
  s = crd.to_json_schema
  Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
end

require_relative "resources/self_signed_issuer"

certmanager_resources = certmanager_chart.template(
  release:   "cert-manager",
  namespace: "cert-manager",
  values: {
    "installCRDs"  => true,
    "replicaCount" => 2,
    "resources" => {
      "requests" => { "cpu" => "50m",  "memory" => "64Mi" },
      "limits"   => { "cpu" => "200m", "memory" => "128Mi" },
    },
    "webhook" => {
      "replicaCount" => 2,
    },
  },
)

manifest = Kube::Cluster::Manifest.new(
  Kube::Cluster["Namespace"].new { metadata.name = "cert-manager" },
  *certmanager_resources,

  SelfSignedIssuer.new,

  Nginx.new(name: "nginx-app", host: "app.example.com"),
)

kinds = manifest.group_by(&:kind)

kinds.sort.each do |kind, resources|
  names = resources.map { |r| r.metadata&.name rescue "?" }.compact
  puts "  %-30s %s" % [kind, names.join(", ")]
end

manifest.write("manifest.yaml")
