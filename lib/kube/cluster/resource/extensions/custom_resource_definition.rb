# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module Extensions
        module CustomResourceDefinition
          def to_json_schema
            h = to_h
            kind     = h.dig(:spec, :names, :kind)
            group    = h.dig(:spec, :group)
            versions = h.dig(:spec, :versions) || []

            version = versions.find { |v| v[:storage] } ||
                      versions.find { |v| v.dig(:schema, :openAPIV3Schema) } ||
                      versions.first

            unless version
              raise ArgumentError, "CRD has no versions"
            end

            version_name = version[:name]
            schema       = version.dig(:schema, :openAPIV3Schema)

            unless schema
              raise ArgumentError, "CRD version #{version_name} has no openAPIV3Schema"
            end

            {
              kind:        kind,
              schema:      deep_stringify_keys(schema),
              api_version: "#{group}/#{version_name}",
            }
          end
        end
      end
    end
  end
end
