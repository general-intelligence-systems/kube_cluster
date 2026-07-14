# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # VictoriaMetrics Anomaly Detection service (vmanomaly). Reads metrics,
        # fits models, and writes anomaly scores back. Provide the model/reader/
        # writer configuration via spec.configRawYaml in the block.
        class VMAnomaly < Kube::Cluster["VMAnomaly"]
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

describe "VictoriaMetrics::VMAnomaly" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMAnomaly
      .new(name: "vmanomaly")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
