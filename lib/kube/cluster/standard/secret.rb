# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class Secret < Kube::Cluster["Secret"]
        def initialize(name:, **data, &block)
          super() {
            metadata.name = name
            data.each { |k, v| stringData[k.to_s] = v }
            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end

test do
  describe "Secret" do
    it "initializes without error" do
      Kube::Cluster::Standard::Secret
        .new(
          name: "my-secret"
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
