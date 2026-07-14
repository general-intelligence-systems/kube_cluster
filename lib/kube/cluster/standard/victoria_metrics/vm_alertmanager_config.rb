# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Alertmanager routing tree and receivers, selected by a VMAlertmanager.
        # Define spec.route and spec.receivers in the block.
        class VMAlertmanagerConfig < Kube::Cluster["VMAlertmanagerConfig"]
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

describe "VictoriaMetrics::VMAlertmanagerConfig" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMAlertmanagerConfig
      .new(name: "vmalertmanagerconfig")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
