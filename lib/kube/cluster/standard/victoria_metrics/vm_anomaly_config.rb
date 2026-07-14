# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Reusable configuration object referenced by a VMAnomaly instance.
        # Define the models/schedulers in the block.
        class VMAnomalyConfig < Kube::Cluster["VMAnomalyConfig"]
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

describe "VictoriaMetrics::VMAnomalyConfig" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMAnomalyConfig
      .new(name: "vmanomalyconfig") { spec.schedulers = {} }
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
