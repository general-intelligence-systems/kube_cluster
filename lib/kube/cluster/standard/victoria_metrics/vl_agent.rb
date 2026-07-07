# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Collects Kubernetes pod logs and remote-writes them to a VLSingle.
        class VLAgent < Kube::Cluster["VLAgent"]
          def initialize(name:, remote_write_url:, &block)
            super() {
              metadata.name          = name
              spec.useStrictSecurity = true
              spec.k8sCollector = {
                enabled:    true,
                msgFields:  %w[msg message log.msg],
                timeFields: %w[time ts timestamp],
              }
              spec.remoteWrite = [{ url: remote_write_url }]
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VLAgent" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VLAgent
      .new(name: "vlagent", remote_write_url: "http://vlsingle-vlsingle.metrics.svc:9428/internal/insert")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
