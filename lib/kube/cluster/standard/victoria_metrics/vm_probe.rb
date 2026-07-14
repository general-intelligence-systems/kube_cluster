# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Blackbox/probe scraping: points a prober (e.g. blackbox_exporter) at a
        # set of targets. Pass the prober URL here and the targets/module in the
        # block via spec.targets and spec.module.
        class VMProbe < Kube::Cluster["VMProbe"]
          def initialize(name:, prober_url:, &block)
            super() {
              metadata.name    = name
              spec.vmProberSpec = { url: prober_url }
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMProbe" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMProbe
      .new(name: "blackbox", prober_url: "http://blackbox-exporter.metrics.svc:9115")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
