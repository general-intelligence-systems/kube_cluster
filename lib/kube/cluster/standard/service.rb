# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class Service < Kube::Cluster["Service"]
        def initialize(name:, ports:, namespace: "default", **options, &block)
          super() {
            metadata.name = name
            metadata.namespace = namespace
            metadata.labels = { "app" => name }
            spec.selector = { "app" => name }
            spec.ports = ports.map do |port|
              { name: "http-#{port}", port: port, targetPort: port, protocol: "TCP" }
            end

            instance_exec(&block) if block_given?
          }
        end
      end
    end
  end
end

__END__

describe "Service" do
  it "initializes without error" do
    Kube::Cluster::Standard::Service
      .new(
        name: "my-secret",
        ports: [],
      )
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
