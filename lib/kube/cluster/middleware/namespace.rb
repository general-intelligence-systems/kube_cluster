# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Middleware
      # Sets metadata.namespace on namespace-scoped resources.
      #
      # @example
      #   stack do
      #     use Middleware::Namespace, "production"
      #   end
      class Namespace < Middleware
        def initialize(namespace, filter: DEFAULT_FILTER, force: false)
          unless force
            raise "Middleware::Namespace is deprecated... use Middleware::SetNamespace"
          end

          super(filter: filter)
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! do |resource|
            filter(resource) do
              if resource.cluster_scoped?
                next resource
              end
              h = resource.to_h
              h[:metadata] ||= {}
              h[:metadata][:namespace] = @namespace
              resource.rebuild(h)
            end
          end
        end
      end
    end
  end
end

