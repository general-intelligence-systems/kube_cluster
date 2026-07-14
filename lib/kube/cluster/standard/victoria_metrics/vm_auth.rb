# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Auth proxy / router that sits in front of VictoriaMetrics components and
        # dispatches requests according to the VMUser objects it selects. Configure
        # user selection and unauthorized-access rules in the block.
        class VMAuth < Kube::Cluster["VMAuth"]
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

describe "VictoriaMetrics::VMAuth" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMAuth
      .new(name: "vmauth")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
