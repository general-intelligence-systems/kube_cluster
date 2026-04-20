require "bundler/setup"
require "kube/cluster"

# Helm Chart → Manifest
#
# Fetches the Bitnami nginx chart, renders it with values,
# and writes the result as YAML.

manifest =
  Kube::Helm::Repo
    .new("bitnami", url: "https://charts.bitnami.com/bitnami")
    .fetch("nginx", version: "18.1.0")
    .apply_values({
      "replicaCount" => 3,
      "service"      => { "type" => "ClusterIP" },
    })

puts manifest.to_yaml
