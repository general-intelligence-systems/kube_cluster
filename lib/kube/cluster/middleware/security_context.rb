# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

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

if __FILE__ == $0
  require "minitest/autorun"

  class SecurityContextMiddlewareTest < Minitest::Test
    Middleware = Kube::Cluster::Middleware

    def test_applies_restricted_profile_by_default
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::SecurityContext.new.call(m)
      h = m.resources.first.to_h
      pod_sc = h.dig(:spec, :template, :spec, :securityContext)
      container_sc = h.dig(:spec, :template, :spec, :containers, 0, :securityContext)

      assert_equal true, pod_sc[:runAsNonRoot]
      assert_equal 1000, pod_sc[:runAsUser]
      assert_equal 1000, pod_sc[:fsGroup]
      assert_equal({ type: "RuntimeDefault" }, pod_sc[:seccompProfile])

      assert_equal false, container_sc[:allowPrivilegeEscalation]
      assert_equal true, container_sc[:readOnlyRootFilesystem]
      assert_equal({ drop: ["ALL"] }, container_sc[:capabilities])
    end

    def test_applies_baseline_profile_via_label
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/security": "baseline" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::SecurityContext.new.call(m)
      h = m.resources.first.to_h
      pod_sc = h.dig(:spec, :template, :spec, :securityContext)
      container_sc = h.dig(:spec, :template, :spec, :containers, 0, :securityContext)

      assert_equal true, pod_sc[:runAsNonRoot]
      assert_nil pod_sc[:seccompProfile]

      assert_equal false, container_sc[:allowPrivilegeEscalation]
      assert_nil container_sc[:readOnlyRootFilesystem]
    end

    def test_applies_baseline_profile_via_constructor_default
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::SecurityContext.new(default: :baseline).call(m)
      h = m.resources.first.to_h
      pod_sc = h.dig(:spec, :template, :spec, :securityContext)

      assert_nil pod_sc[:seccompProfile]
    end

    def test_label_overrides_constructor_default
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/security": "restricted" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::SecurityContext.new(default: :baseline).call(m)
      h = m.resources.first.to_h
      pod_sc = h.dig(:spec, :template, :spec, :securityContext)

      assert_equal({ type: "RuntimeDefault" }, pod_sc[:seccompProfile])
    end

    def test_applies_to_all_containers
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "app", image: "app:latest" },
          { name: "sidecar", image: "sidecar:latest" },
        ]
      })

      Middleware::SecurityContext.new.call(m)
      containers = m.resources.first.to_h.dig(:spec, :template, :spec, :containers)

      containers.each do |c|
        assert_equal false, c.dig(:securityContext, :allowPrivilegeEscalation)
      end
    end

    def test_skips_non_pod_bearing_resources
      resource = Kube::Cluster["ConfigMap"].new { metadata.name = "config" }
      m = manifest(resource)

      Middleware::SecurityContext.new.call(m)

      assert_equal resource.to_h, m.resources.first.to_h
    end

    def test_raises_on_unknown_profile
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/security": "yolo" }
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      error = assert_raises(ArgumentError) do
        Middleware::SecurityContext.new.call(m)
      end

      assert_includes error.message, "yolo"
    end

    def test_preserves_existing_pod_security_context
      m = manifest(Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        spec.selector.matchLabels = { app: "web" }
        spec.template.metadata.labels = { app: "web" }
        spec.template.spec.securityContext = { runAsUser: 9999 }
        spec.template.spec.containers = [
          { name: "web", image: "nginx:latest" },
        ]
      })

      Middleware::SecurityContext.new.call(m)
      pod_sc = m.resources.first.to_h.dig(:spec, :template, :spec, :securityContext)

      # Existing value wins
      assert_equal 9999, pod_sc[:runAsUser]
      # Middleware fills in missing values
      assert_equal true, pod_sc[:runAsNonRoot]
    end

    private

      def manifest(*resources)
        m = Kube::Cluster::Manifest.new
        resources.each { |r| m << r }
        m
      end
  end
end
