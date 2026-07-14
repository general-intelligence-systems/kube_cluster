# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Declares how to scrape the pods selected by the app.kubernetes.io/name
        # label (the pod-selector analogue of VMServiceScrape), relabelling the
        # metrics onto a job.
        class VMPodScrape < Kube::Cluster["VMPodScrape"]
          def initialize(name:, job:, match_name:, port:, &block)
            super() {
              metadata.name           = name
              spec.selector           = { matchLabels: { "app.kubernetes.io/name" => match_name } }
              spec.podMetricsEndpoints = [{ port: port, relabelConfigs: [{ targetLabel: "job", replacement: job }] }]
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMPodScrape" do
  it "initializes without error" do
    Kube::Cluster::Standard::VictoriaMetrics::VMPodScrape
      .new(name: "opencost", job: "opencost", match_name: "opencost", port: "http")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
