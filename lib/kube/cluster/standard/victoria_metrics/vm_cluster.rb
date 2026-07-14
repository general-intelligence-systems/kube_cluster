# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # HA/clustered VictoriaMetrics: vmstorage + vmselect + vminsert
        # components (the horizontally-scalable alternative to VMSingle).
        # Configure the three components in the block.
        class VMCluster < Kube::Cluster["VMCluster"]
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

describe "VictoriaMetrics::VMCluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMCluster
      .new(name: "vmcluster")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
