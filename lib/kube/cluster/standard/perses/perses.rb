# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module Perses
        # The Perses application instance the operator reconciles. Defaults to a
        # file-backed database under /perses.
        class Perses < Kube::Cluster["Perses"]
          def initialize(name:, image:, port: 8080, &block)
            super() {
              metadata.name      = name
              spec.image         = image
              spec.containerPort = port
              spec.config = {
                database: {
                  file: {
                    folder:    "/perses",
                    extension: "json",
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

test do
  describe "Perses::Perses" do
    it "initializes without error" do
      Kube::Cluster::Standard::Perses::Perses
        .new(name: "perses", image: "persesdev/perses:latest")
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
