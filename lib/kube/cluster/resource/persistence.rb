# frozen_string_literal: true

require "json"
require "open3"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      module Persistence
        def apply
          json = JSON.generate(deep_stringify_keys(to_h))
          kubectl("apply", "-f", "-", stdin: json)
          reload
          true
        end

        def patch(type: "strategic")
          raise Kube::CommandError, "cannot patch a resource without a name" unless persisted?

          diff = patch_data
          return false if diff.empty?

          json = JSON.generate(deep_stringify_keys(diff))
          kubectl(
            "patch", resource_type, name,
            *ns_flags,
            "--type", type,
            "-p", json
          )
          reload
          true
        end

        def delete
          raise Kube::CommandError, "cannot delete a resource without a name" unless persisted?

          kubectl("delete", resource_type, name, *ns_flags)
          true
        end

        def reload
          raise Kube::CommandError, "cannot reload a resource without a name" unless persisted?

          json = kubectl("get", resource_type, name, *ns_flags, "-o", "json")
          hash = JSON.parse(json)
          @data = BlackHoleStruct.new(hash)
          snapshot!
          self
        end

        private

          def kubectl(*args, stdin: nil)
            cmd = ["kubectl", *args]
            stdout, stderr, status = Open3.capture3(*cmd, stdin_data: stdin)

            unless status.success?
              raise Kube::CommandError.from_kubectl(
                subcommand: args.first,
                stderr: stderr.strip,
                exit_code: status.exitstatus
              )
            end

            stdout
          end
      end
    end
  end
end
