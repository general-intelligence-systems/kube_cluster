# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class Secret < Kube::Cluster["Secret"]
        KeyRef = Struct.new(:secret, :key_name)

        def initialize(name:, **data, &block)
          super() {
            metadata.name = name
            data.each { |k, v| stringData[k.to_s] = v }
            instance_exec(&block) if block_given?
          }
        end

        def secret_name
          to_h.dig(:metadata, :name)
        end

        def key(key_name)
          KeyRef.new(self, key_name)
        end
      end
    end
  end
end

__END__

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
