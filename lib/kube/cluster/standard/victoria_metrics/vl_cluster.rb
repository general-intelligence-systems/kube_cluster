# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # HA/clustered VictoriaLogs: vlstorage + vlselect + vlinsert components
        # (the horizontally-scalable alternative to VLSingle). Retention lives on
        # the vlstorage component, so configure the components in the block.
        class VLCluster < Kube::Cluster["VLCluster"]
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

describe "VictoriaMetrics::VLCluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VLCluster
      .new(name: "vlcluster")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
