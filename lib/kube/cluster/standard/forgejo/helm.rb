# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module Forgejo
        class Helm < Kube::Cluster["HelmChart"]

          CHART_VERSION = "16.2.1"

          def initialize(
            domain:,
            chart_version: CHART_VERSION,
            target_namespace: "default",
            storage_size: "200Gi",
            storage_class: "local-path",
            node_selector: nil,
            &block
          )
            super {
              metadata.name = "forgejo"
              metadata.namespace = "kube-system"
              spec.version = chart_version
              spec.chart = "oci://codeberg.org/forgejo-contrib/forgejo"
              spec.targetNamespace = target_namespace
              spec.valuesContent = <<~YAML
                gitea:
                  config:
                    server:
                      ROOT_URL: https://#{domain}/
                      DOMAIN: #{domain}
                      SSH_DOMAIN: #{domain}
                persistence:
                  enabled: true
                  size: #{storage_size}
                  storageClass: #{storage_class}
                #{node_selector ? "nodeSelector:\n  kubernetes.io/hostname: #{node_selector}" : ""}
              YAML

              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "Forgejo::Helm" do
  it "initializes without error" do
    Kube::Cluster::Standard::Forgejo::Helm
      .new(
        domain: "git.facebook.com"
      )
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
