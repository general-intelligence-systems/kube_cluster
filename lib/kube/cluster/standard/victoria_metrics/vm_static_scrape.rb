# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Scrapes a fixed set of static targets (host:port) under a named job —
        # for endpoints that have no Service/Pod to select. Extra per-endpoint
        # settings (path, scheme, labels) can be added in the block.
        class VMStaticScrape < Kube::Cluster["VMStaticScrape"]
          def initialize(name:, job:, targets:, &block)
            super() {
              metadata.name       = name
              spec.jobName        = job
              spec.targetEndpoints = [{ targets: Array(targets) }]
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMStaticScrape" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMStaticScrape
      .new(name: "external", job: "external", targets: ["10.0.0.1:9100"])
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
