# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Merges labels into +metadata.labels+ on every resource.
        # Existing labels are preserved; the supplied labels act as defaults
        # that can be overridden per-resource.
        #
        #   stack do
        #     use Middleware::Labels, app: "web-app", managed_by: "kube_cluster"
        #   end
        #
        # The keyword arguments are converted to standard label keys:
        #
        #   app:        -> "app.kubernetes.io/name"
        #   instance:   -> "app.kubernetes.io/instance"
        #   version:    -> "app.kubernetes.io/version"
        #   component:  -> "app.kubernetes.io/component"
        #   part_of:    -> "app.kubernetes.io/part-of"
        #   managed_by: -> "app.kubernetes.io/managed-by"
        #
        # Any unrecognized keys are passed through as-is (string or symbol).
        #
        class Labels < Middleware
          STANDARD_KEYS = {
            app:        :"app.kubernetes.io/name",
            instance:   :"app.kubernetes.io/instance",
            version:    :"app.kubernetes.io/version",
            component:  :"app.kubernetes.io/component",
            part_of:    :"app.kubernetes.io/part-of",
            managed_by: :"app.kubernetes.io/managed-by",
          }.freeze

          def initialize(**labels)
            @labels = normalize(labels)
          end

          def call(resource)
            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:labels] = @labels.merge(h[:metadata][:labels] || {})
            rebuild(resource, h)
          end

          private

            def normalize(labels)
              labels.each_with_object({}) do |(key, value), result|
                normalized_key = STANDARD_KEYS.fetch(key, key)
                result[normalized_key] = value.to_s
              end
            end
        end
      end
    end
  end
end
