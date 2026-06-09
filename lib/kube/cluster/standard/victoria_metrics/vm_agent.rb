# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Scrapes targets (selecting all scrape objects by default) and
        # remote-writes the samples into a VMSingle/VMCluster.
        class VMAgent < Kube::Cluster["VMAgent"]
          def initialize(name:, remote_write_url:, scrape_interval: "30s", select_all: true, &block)
            super() {
              metadata.name           = name
              spec.selectAllByDefault = select_all
              spec.scrapeInterval     = scrape_interval
              spec.remoteWrite        = [{ url: remote_write_url }]
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

test do
  describe "VictoriaMetrics::VMAgent" do
    it "initializes without error" do
      Kube::Cluster::Standard::VictoriaMetrics::VMAgent
        .new(name: "vmagent", remote_write_url: "http://vmsingle-vmsingle.metrics.svc:8429/api/v1/write")
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
