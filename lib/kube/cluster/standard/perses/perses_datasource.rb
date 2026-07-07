# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module Perses
        # A Perses datasource, proxied over HTTP to the given url.
        class PersesDatasource < Kube::Cluster["PersesDatasource"]
          def initialize(name:, plugin_kind:, url:, display_name: nil, default: false, &block)
            super() {
              metadata.name = name
              spec.config = {
                default: default,
                display: { name: display_name || name },
                plugin: {
                  kind: plugin_kind,
                  spec: {
                    proxy: {
                      kind: "HTTPProxy",
                      spec: { url: url },
                    },
                  },
                },
              }
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "Perses::PersesDatasource" do
  it "initializes without error" do
    Kube::Cluster::Standard::Perses::PersesDatasource
      .new(
        name: "victoriametrics",
        plugin_kind: "PrometheusDatasource",
        url: "http://vmsingle-vmsingle.metrics.svc:8429",
      )
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
