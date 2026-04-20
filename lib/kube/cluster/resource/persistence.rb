# frozen_string_literal: true

require "json"
require "open3"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module Persistence
        def name
          to_h.dig(:metadata, :name)&.to_s
        end

        def persisted?
          !name.nil? && !name.empty?
        end

        def apply
          JSON.generate(deep_stringify_keys(to_h)).then do |json|
            kubectl("apply", "-f", "-", stdin: json)
            reload
            true
          end
        end

        def patch(type: "strategic")
          if persisted?
            diff = patch_data

            if diff.empty?
              false
            else
              json = JSON.generate(deep_stringify_keys(diff))
              kubectl("patch", kind.downcase, name, *namespace_flags, "--type", type, "-p", json)
              reload
              true
            end
          else
            raise Kube::CommandError, "cannot patch a resource without a name"
          end
        end

        def delete
          if persisted?
            kubectl("delete", kind.downcase, name, *namespace_flags)
            true
          else
            raise Kube::CommandError, "cannot delete a resource without a name"
          end
        end

        def reload
          if persisted?
            tap do
              kubectl("get", kind.downcase, name, *namespace_flags, "-o", "json").then do |json|
                JSON.parse(json).then do |hash|
                  @data = deep_symbolize_keys(hash)
                  snapshot!
                end
              end
            end
          else
            raise Kube::CommandError, "cannot reload a resource without a name"
          end
        end

        private

          def namespace_flags
            ns = to_h.dig(:metadata, :namespace)
            ns ? ["--namespace", ns.to_s] : []
          end

          def kubectl(*args)
            @cluster.connection.ctl.run(args.join(" "))
          end
      end
    end
  end
end
