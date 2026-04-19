# frozen_string_literal: true

module Kube
  module Cluster
    class Middleware
      # Injects pod and container security contexts on pod-bearing resources.
      #
      # Reads the +app.kubernetes.io/security+ label. When the label
      # is absent, the middleware applies the default profile.
      #
      #   Kube::Cluster["Deployment"].new {
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

        def call(manifest)
          manifest.resources.map! do |resource|
            next resource unless resource.pod_bearing?

            profile_name = resource.label(LABEL) || @default
            profile = PROFILES.fetch(profile_name.to_s) do
              raise ArgumentError, "Unknown security profile: #{profile_name.inspect}. " \
                "Valid profiles: #{PROFILES.keys.join(', ')}"
            end

            h = resource.to_h
            pod_spec = resource.pod_template(h)
            next resource unless pod_spec

            pod_spec[:securityContext] = deep_merge(profile[:pod], pod_spec[:securityContext] || {})

            resource.each_container(pod_spec) do |container|
              container[:securityContext] = deep_merge(profile[:container], container[:securityContext] || {})
            end

            resource.rebuild(h)
          end
        end
      end
    end
  end
end
