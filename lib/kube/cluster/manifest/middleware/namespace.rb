# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
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

          def call(resource)
            return resource if cluster_scoped?(resource)

            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:namespace] = @namespace
            rebuild(resource, h)
          end
        end
      end
    end
  end
end
