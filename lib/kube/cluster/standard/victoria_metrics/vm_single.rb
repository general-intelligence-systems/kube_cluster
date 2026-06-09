# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Single-node VictoriaMetrics time-series database.
        class VMSingle < Kube::Cluster["VMSingle"]
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

test do
  describe "VictoriaMetrics::VMSingle" do
    it "initializes without error" do
      Kube::Cluster::Standard::VictoriaMetrics::VMSingle
        .new(name: "vmsingle")
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
