require "bundler/setup"
require "kube/cluster"

CertManager = Kube::Helm::Repo
  .new("jetstack", url: "https://charts.jetstack.io")
  .fetch("cert-manager", version: "1.17.2")

CertManager.crds.each do |crd|
  crd.to_json_schema.then do |s|
    Kube::Schema.register(
      s[:kind],
      schema: s[:schema],
      api_version: s[:api_version]
    )
  end
end

require_relative "resources/namespace"
require_relative "resources/nginx"
require_relative "resources/self_signed_issuer"

manifest =
  Kube::Cluster::Manifest.new(
    CertManager.apply_values(
      {
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
      release:   "cert-manager",
      namespace: "cert-manager",
    ),

    Namespace.new(name: "cert-manager"),
    Nginx.new(name: "nginx-app", host: "app.example.com"),
    SelfSignedIssuer.new,
  )

manifest.to_yaml
