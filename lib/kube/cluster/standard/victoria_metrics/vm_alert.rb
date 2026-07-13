# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # Evaluates VMRule recording/alerting rules (selecting all by default).
        # Recording-rule output is written back via remote_write_url; a notifier
        # is only needed for alerting rules, so it is optional.
        class VMAlert < Kube::Cluster["VMAlert"]
          def initialize(name:, datasource_url:, remote_write_url:, remote_read_url: nil,
                         notifier_url: nil, evaluation_interval: nil, select_all: true, &block)
            super() {
              metadata.name           = name
              spec.selectAllByDefault = select_all
              spec.datasource         = { url: datasource_url }
              spec.remoteWrite        = { url: remote_write_url }
              spec.remoteRead         = { url: remote_read_url }      if remote_read_url
              spec.notifiers          = [{ url: notifier_url }]       if notifier_url
              spec.evaluationInterval = evaluation_interval           if evaluation_interval
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMAlert" do
  it "wires datasource and remote-write for recording rules" do
    yaml = Kube::Cluster::Standard::VictoriaMetrics::VMAlert.new(
      name:             "vmalert",
      datasource_url:   "http://vmsingle-vmsingle.metrics.svc:8429/prometheus",
      remote_write_url: "http://vmsingle-vmsingle.metrics.svc:8429/api/v1/write"
    ).to_yaml

    yaml.include?("operator.victoriametrics.com/v1beta1").should == true
    yaml.include?("selectAllByDefault").should == true
    yaml.include?("/api/v1/write").should == true
  end
end
