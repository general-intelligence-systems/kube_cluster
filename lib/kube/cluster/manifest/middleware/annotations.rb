# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Merges annotations into +metadata.annotations+ on every resource.
        # Existing annotations are preserved; the supplied annotations act
        # as defaults that can be overridden per-resource.
        #
        #   stack do
        #     use Middleware::Annotations,
        #       "prometheus.io/scrape": "true",
        #       "prometheus.io/port":   "9090"
        #   end
        #
        class Annotations < Middleware
          def initialize(**annotations)
            @annotations = annotations.transform_keys(&:to_sym).transform_values(&:to_s)
          end

          def call(resource)
            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:annotations] = @annotations.merge(h[:metadata][:annotations] || {})
            rebuild(resource, h)
          end
        end
      end
    end
  end
end
