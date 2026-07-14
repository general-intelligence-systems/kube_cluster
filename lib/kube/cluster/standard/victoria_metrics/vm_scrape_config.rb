# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Generic scrape configuration supporting the full range of service-
        # discovery mechanisms (static, kubernetes, http, ec2, consul, …). Declare
        # the discovery configs and relabelling in the block.
        class VMScrapeConfig < Kube::Cluster["VMScrapeConfig"]
          def initialize(name:, &block)
            super() {
              metadata.name = name
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMScrapeConfig" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMScrapeConfig
      .new(name: "vmscrapeconfig")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
