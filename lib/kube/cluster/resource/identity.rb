# frozen_string_literal: true

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module Identity
        def kind       = @data.kind.to_s
        def api_version = @data.apiVersion.to_s
        def name       = @data.metadata.name.to_s
        def namespace  = @data.metadata.namespace.to_s

        def persisted?
          !name.empty?
        end

        private

          def resource_type
            kind.downcase
          end

          def ns_flags
            ns = namespace
            ns.empty? ? [] : ["-n", ns]
          end
      end
    end
  end
end
