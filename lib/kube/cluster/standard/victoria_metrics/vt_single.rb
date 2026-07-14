# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Single-node VictoriaTraces store.
        class VTSingle < Kube::Cluster["VTSingle"]
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

describe "VictoriaMetrics::VTSingle" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VTSingle
      .new(name: "vtsingle")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
