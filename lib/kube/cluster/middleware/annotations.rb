# frozen_string_literal: true

module Kube
  module Cluster
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

        def call(manifest)
          manifest.resources.map! do |resource|
            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:annotations] = @annotations.merge(h[:metadata][:annotations] || {})
            resource.rebuild(h)
          end
        end
      end
    end
  end
end
