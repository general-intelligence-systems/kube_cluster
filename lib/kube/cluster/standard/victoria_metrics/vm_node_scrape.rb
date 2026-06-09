# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Scrapes node-level endpoints (e.g. the kubelet) over HTTPS using the
        # in-cluster service-account token.
        class VMNodeScrape < Kube::Cluster["VMNodeScrape"]
          def initialize(name:, job:, path: nil, interval: "30s", &block)
            super() {
              metadata.name        = name
              spec.scheme          = "https"
              spec.tlsConfig       = { insecureSkipVerify: true }
              spec.bearerTokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              spec.honorLabels     = true
              spec.interval        = interval
              spec.path            = path if path
              spec.relabelConfigs  = [{ targetLabel: "job", replacement: job }]
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

test do
  describe "VictoriaMetrics::VMNodeScrape" do
    it "initializes without error" do
      Kube::Cluster::Standard::VictoriaMetrics::VMNodeScrape
        .new(name: "kubelet", job: "kubelet", path: "/metrics")
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
