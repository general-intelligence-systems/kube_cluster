# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Single-node VictoriaLogs store.
        class VLSingle < Kube::Cluster["VLSingle"]
          def initialize(name:, retention_period: "30d", &block)
            super() {
              metadata.name        = name
              spec.retentionPeriod = retention_period
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VLSingle" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VLSingle
      .new(name: "vlsingle")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
