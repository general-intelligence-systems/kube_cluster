# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster   
    module Standard
      module GatewayApi
        #class HTTPRoute < Kube::Cluster::Manifest
        #end
      end
    end
  end
end

test do
  #describe "GatewayApi::HTTPRoute" do
  #  it "initializes without error" do
  #    Kube::Cluster::Standard::GatewayApi::HTTPRoute
  #      .new(
  #        name: nil,
  #        hostname: nil,
  #        service: nil,
  #        namespace: nil,
  #        port: nil,
  #      )
  #      .to_yaml
  #      .is_a?(String)
  #      .should == true
  #  end
  #end
end
