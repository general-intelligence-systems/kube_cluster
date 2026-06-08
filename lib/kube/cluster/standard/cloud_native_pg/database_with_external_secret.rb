# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        class DatabaseWithExternalSecret < Kube::Cluster::Manifest
          def initialize(name:, cluster: "postgres", owner: "app", &block)
            database = Kube::Cluster["Database"].new {
              metadata.name = name
              spec.cluster = { name: cluster }
              spec.databaseReclaimPolicy = "retain"
              spec.ensure = "present"
              spec.name = name
              spec.owner = owner
            }

            external_secret = CloudNativePg::ExternalSecret.new(name: name)

            super(database, external_secret)
            instance_exec(&block) if block
          end
        end
      end
    end
  end
end

test do
  describe "CloudNativePg::DatabaseWithExternalSecret" do
    it "initializes without error" do
      Kube::Cluster::Standard::CloudNativePg::DatabaseWithExternalSecret
        .new(
          name: "my-example-cluster"
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
