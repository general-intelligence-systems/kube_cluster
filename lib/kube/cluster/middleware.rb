# frozen_string_literal: true

require_relative "middleware/stack"
require_relative "middleware/namespace"
require_relative "middleware/labels"
require_relative "middleware/annotations"
require_relative "middleware/resource_preset"
require_relative "middleware/security_context"
require_relative "middleware/pod_anti_affinity"
require_relative "middleware/service_for_deployment"
require_relative "middleware/ingress_for_service"
require_relative "middleware/hpa_for_deployment"

module Kube
  module Cluster
    # Base class for manifest middleware.
    #
    # Middleware receives the full manifest and mutates it in place.
    # Each middleware is responsible for iterating resources as needed.
    #
    # Transform example:
    #
    #   class AddTeamLabel < Middleware
    #     def call(manifest)
    #       manifest.resources.map! do |resource|
    #         h = resource.to_h
    #         h[:metadata][:labels][:"app.kubernetes.io/team"] = "platform"
    #         resource.rebuild(h)
    #       end
    #     end
    #   end
    #
    # Generative example:
    #
    #   class ServiceForDeployment < Middleware
    #     def call(manifest)
    #       generated = []
    #       manifest.resources.each do |resource|
    #         next unless resource.pod_bearing?
    #         generated << build_service_from(resource)
    #       end
    #       manifest.resources.concat(generated)
    #     end
    #   end
    #
    class Middleware
      def initialize(**opts)
        @opts = opts
      end

      # Override in subclasses. Receives the full manifest,
      # mutates it in place.
      def call(manifest)
      end

      private

        def deep_merge(base, overlay)
          base.merge(overlay) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end
    end
  end
end
