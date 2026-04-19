# frozen_string_literal: true

require "json"
require "open3"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module Persistence
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
              kubectl("patch", resource_type, name, *ns_flags, "--type", type, "-p", json)
              reload
              true
            end
          else
            raise Kube::CommandError, "cannot patch a resource without a name"
          end
        end

        def delete
          if persisted?
            kubectl("delete", resource_type, name, *ns_flags)
            true
          else
            raise Kube::CommandError, "cannot delete a resource without a name"
          end
        end

        def reload
          if persisted?
            tap do
              kubectl("get", resource_type, name, *ns_flags, "-o", "json").then do |json|
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

          def kubectl(*args)
            @cluster.connection.ctl.run(args.join(" "))
          end
      end
    end
  end
end
