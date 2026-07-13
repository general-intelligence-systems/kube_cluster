# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        # A CloudNativePG Cluster CR. Thin wrapper: sets metadata, leaves the
        # (large, deployment-specific) spec to the block.
        class Cluster < Kube::Cluster["Cluster"]
          def initialize(name: "postgres", namespace: nil, &block)
            super() {
              metadata.name = name
              metadata.namespace = namespace if namespace
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "CloudNativePg::Cluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::CloudNativePg::Cluster
      .new(name: "postgres", namespace: "cloudnative-pg") {
        spec.instances = 1
        spec.storage = { size: "1Gi" }
      }
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
