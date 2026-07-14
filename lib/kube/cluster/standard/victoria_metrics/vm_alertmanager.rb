# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Managed Alertmanager instance. Notification routing/receivers can be
        # supplied inline via spec.configRawYaml or selected from
        # VMAlertmanagerConfig objects; configure that in the block.
        class VMAlertmanager < Kube::Cluster["VMAlertmanager"]
          def initialize(name:, replica_count: 1, &block)
            super() {
              metadata.name     = name
              spec.replicaCount = replica_count
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMAlertmanager" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMAlertmanager
      .new(name: "vmalertmanager")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
