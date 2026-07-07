# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        #class Cluster < Kube::Cluster["Cluster"]
        #end
      end
    end
  end
end

__END__

#describe "CloudNativePg::Cluster" do
#  it "initializes without error" do
#    Kube::Cluster::Standard::CloudNativePg::Cluster
#      .new()
#      .to_yaml
#      .is_a?(String)
#      .should == true
#  end
#end
