# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Multi-zone/distributed VictoriaMetrics topology. The full shape (zones,
        # common settings) is configured in the block.
        class VMDistributed < Kube::Cluster["VMDistributed"]
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

describe "VictoriaMetrics::VMDistributed" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMDistributed
      .new(name: "vmdistributed") { spec.retain = true }
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
