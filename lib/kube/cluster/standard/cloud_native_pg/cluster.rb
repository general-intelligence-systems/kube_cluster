# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        # A CloudNativePG Cluster CR, resolved to postgresql.cnpg.io/v1/Cluster.
        # The (large, deployment-specific) spec is supplied via the block.
        class Cluster < Kube::Cluster["Cluster"]
        end
      end
    end
  end
end

__END__

describe "CloudNativePg::Cluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::CloudNativePg::Cluster
      .new {
        metadata.name = "postgres"
        spec.instances = 1
        spec.storage = { size: "1Gi" }
      }
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
