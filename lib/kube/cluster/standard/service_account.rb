# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class ServiceAccount < Kube::Cluster["ServiceAccount"]
        def initialize(name:, namespace: nil, &block)
          super() do
            metadata.name = name
            metadata.namespace = namespace if namespace
            instance_exec(&block) if block
          end
        end

        def name
          to_h.dig(:metadata, :name)
        end

        def namespace
          to_h.dig(:metadata, :namespace)
        end
      end
    end
  end
end

test do
  describe "ServiceAccount" do
    it "initializes without error" do
      Kube::Cluster::Standard::ServiceAccount
        .new(name: "my-sa")
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
