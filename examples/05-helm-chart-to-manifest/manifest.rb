require "bundler/setup"
require "kube/cluster"

# Helm Chart → Manifest
#
# Renders the Bitnami nginx chart into typed Ruby objects
# and writes the result as YAML.

repo = Kube::Helm::Repo
  .new("bitnami", url: "https://charts.bitnami.com/bitnami")
  .add
  .update

repo.chart("nginx", version: "18.1.0")
  .template(
    release:   "my-nginx",
    namespace: "production",
    values: {
      "replicaCount" => 3,
      "service"      => { "type" => "ClusterIP" },
    }
  ).write("manifest.yaml")
