# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        module Helm
          class Operator < Kube::Cluster["HelmChart"]
            def initialize(&block)
              super {
                metadata.name = "cloudnative-pg"
                metadata.namespace = "kube-system"
                spec.chart = "cloudnative-pg"
                spec.version = "0.28.2"
                spec.repo = "https://cloudnative-pg.github.io/charts"
                spec.targetNamespace = "cnpg-system"
                spec.createNamespace = true

                instance_exec(&block) if block
              }
            end
          end

          # You shouldn't really need this... it's a dependency of
          # the Operator chart...
          #
          # class Cluster < Kube::Cluster["HelmChart"]
          #   def initialize(&block)
          #     super {
          #       metadata.name = "cloudnative-pg"
          #       metadata.namespace = "kube-system"
          #       spec.chart = "cluster"
          #       spec.version = "0.6.1"
          #       spec.repo = "https://cloudnative-pg.github.io/charts"
          #       spec.targetNamespace = "cnpg-system"
          #       spec.createNamespace = true

          #       instance_exec(&block) if block
          #     }
          #   end
          # end

          class Barman < Kube::Cluster["HelmChart"]
            def initialize(&block)
              super {
                metadata.name = "cloudnative-pg"
                metadata.namespace = "kube-system"
                spec.chart = "plugin-barman-cloud"
                spec.version = "0.6.0"
                spec.repo = "https://cloudnative-pg.github.io/charts"
                spec.targetNamespace = "cnpg-system"
                spec.createNamespace = true

                instance_exec(&block) if block
              }
            end
          end
        end
      end
    end
  end
end

test do
  it "Operator initializes without error" do
    Kube::Cluster::Standard::CloudNativePg::Helm::Operator
      .new()
      .to_yaml
      .is_a?(String)
      .should == true
  end

  # it "Cluster initializes without error" do
  #   Kube::Cluster::Standard::CloudNativePg::Helm::Cluster
  #     .new()
  #     .to_yaml
  #     .is_a?(String)
  #     .should == true
  # end

  it "Barman initializes without error" do
    Kube::Cluster::Standard::CloudNativePg::Helm::Barman
      .new()
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
