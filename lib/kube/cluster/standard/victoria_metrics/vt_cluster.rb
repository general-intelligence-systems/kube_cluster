# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # HA/clustered VictoriaTraces: storage + select + insert components
        # (the horizontally-scalable alternative to VTSingle). Retention lives on
        # the storage component, so configure the components in the block.
        class VTCluster < Kube::Cluster["VTCluster"]
          def initialize(name:, &block)
            super() {
              metadata.name = name
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VTCluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VTCluster
      .new(name: "vtcluster")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
