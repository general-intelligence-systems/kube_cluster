# frozen_string_literal: true

require "bundler/setup"
require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Sets +metadata.namespace+ on all namespace-scoped resources,
      # skipping HelmCharts and resources that already have a
      # non-default namespace set.
      #
      #   use SetNamespace, 'authelia'
      #
      class SetNamespace < Middleware
        def initialize(namespace)
          super(filter: ->(r) { r.kind != 'HelmChart' })
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! { |resource|
            filter(resource) {
              next resource if resource.cluster_scoped?

              h = resource.to_h
              h[:metadata] ||= {}

              unless h[:metadata][:namespace] && h[:metadata][:namespace] != 'default'
                h[:metadata][:namespace] = @namespace
              end

              # A RoleBinding's ServiceAccount subjects need an explicit
              # namespace; fill in any left blank with the target namespace so
              # same-namespace bindings (e.g. ServiceAccountWithRole) resolve.
              if h[:kind] == 'RoleBinding' && h[:subjects].is_a?(Array)
                h[:subjects] = h[:subjects].map { |subject|
                  if subject[:kind] == 'ServiceAccount' &&
                     (subject[:namespace].nil? || subject[:namespace].to_s.empty?)
                    subject.merge(namespace: @namespace)
                  else
                    subject
                  end
                }
              end

              resource.rebuild(h)
            }
          }
        end
      end
    end
  end
end
