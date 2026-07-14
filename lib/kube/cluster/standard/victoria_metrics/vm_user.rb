# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # A user/route definition consumed by VMAuth: maps credentials to a set of
        # upstream target refs. Pass the routing in the block via spec.targetRefs.
        class VMUser < Kube::Cluster["VMUser"]
          def initialize(name:, username: nil, &block)
            super() {
              metadata.name = name
              spec.username = username if username
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMUser" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMUser
      .new(name: "vmuser", username: "reader") {
        spec.targetRefs = [{ crd: { kind: "VMSingle", name: "vmsingle", namespace: "metrics" }, paths: ["/"] }]
      }
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
