# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module KubeVirt
        class VirtualMachine < Kube::Cluster['VirtualMachine']
          def initialize(name:, &block)
            super() {
              metadata.name = name
              spec.template.metadata.labels = { 'kubevirt.io/domain' => name }
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "KubeVirt::VirtualMachine" do
  it "initializes without error" do
    Kube::Cluster::Standard::KubeVirt::VirtualMachine
      .new(
        name: "my-virtual-machine"
      )
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
