# frozen_string_literal: true

module Kube
  module Cluster
    class Manifest < Kube::Schema::Manifest
      class Middleware
        # Injects pod and container security contexts on pod-bearing resources.
        #
        # Reads the +app.kubernetes.io/security+ label. When the label
        # is absent, the middleware applies the default profile.
        #
        #   Kube::Schema["Deployment"].new {
        #     metadata.labels = { "app.kubernetes.io/security": "restricted" }
        #     ...
        #   }
        #
        # Available profiles: +restricted+ (default), +baseline+.
        #
        #   stack do
        #     use Middleware::SecurityContext                      # default: restricted
        #     use Middleware::SecurityContext, default: :baseline  # change default
        #   end
        #
        class SecurityContext < Middleware
          LABEL = :"app.kubernetes.io/security"

          PROFILES = {
            "restricted" => {
              pod: {
                runAsNonRoot: true,
                runAsUser:    1000,
                runAsGroup:   1000,
                fsGroup:      1000,
                seccompProfile: { type: "RuntimeDefault" },
              },
              container: {
                allowPrivilegeEscalation: false,
                readOnlyRootFilesystem:   true,
                capabilities:             { drop: ["ALL"] },
              },
            },
            "baseline" => {
              pod: {
                runAsNonRoot: true,
                runAsUser:    1000,
                runAsGroup:   1000,
                fsGroup:      1000,
              },
              container: {
                allowPrivilegeEscalation: false,
              },
            },
          }.freeze

          def initialize(default: :restricted)
            @default = default.to_s
          end

          def call(resource)
            return resource unless pod_bearing?(resource)

            profile_name = label(resource, LABEL) || @default
            profile = PROFILES.fetch(profile_name.to_s) do
              raise ArgumentError, "Unknown security profile: #{profile_name.inspect}. " \
                "Valid profiles: #{PROFILES.keys.join(', ')}"
            end

            h = resource.to_h
            pod_spec = pod_template(h)
            return resource unless pod_spec

            pod_spec[:securityContext] = deep_merge(profile[:pod], pod_spec[:securityContext] || {})

            each_container(pod_spec) do |container|
              container[:securityContext] = deep_merge(profile[:container], container[:securityContext] || {})
            end

            rebuild(resource, h)
          end
        end
      end
    end
  end
end
