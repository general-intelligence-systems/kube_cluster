# frozen_string_literal: true

module Kube
  module Cluster
    class Middleware
      # Sets +metadata.namespace+ on all namespace-scoped resources.
      # Cluster-scoped kinds (Namespace, ClusterRole, etc.) are skipped.
      #
      #   stack do
      #     use Middleware::Namespace, "production"
      #   end
      #
      class Namespace < Middleware
        def initialize(namespace)
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! do |resource|
            next resource if resource.cluster_scoped?

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
