# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Legacy VictoriaLogs kind (operator.victoriametrics.com/v1beta1). New
        # deployments should prefer VLSingle (v1); this wrapper exists for
        # completeness / migrating existing objects. Spec is configured in block.
        class VLogs < Kube::Cluster["VLogs"]
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

describe "VictoriaMetrics::VLogs" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VLogs
      .new(name: "vlogs")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
