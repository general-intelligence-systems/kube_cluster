# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CDI
        #class DataVolume < Kube::Cluster['DataVolume']
        #  def initialize(name:, &block)
        #    super() {
        #      metadata.name = name
        #      instance_exec(&block) if block
        #    }
        #  end
        #end
      end
    end
  end
end

__END__

#describe "CDI::DataVolume" do
#  it "initializes without error" do
#    Kube::Cluster::Standard::CDI::DataVolume
#      .new(
#        name: "my-example-volume"
#      )
#      .to_yaml
#      .is_a?(String)
#      .should == true
#  end
#end
