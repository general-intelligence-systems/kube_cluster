# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

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

        def call(manifest)
          default = @opts.fetch(:default, :restricted).to_s

          manifest.resources.map! do |resource|
            filter(resource) do
              next resource unless resource.pod_bearing?

              profile_name = resource.label(LABEL) || default
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
end

test do
  Middleware = Kube::Cluster::Middleware

  it "applies_restricted_profile_by_default" do
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

    pod_sc[:runAsNonRoot].should == true
  end

  it "applies_baseline_profile_via_label" do
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

    pod_sc[:runAsNonRoot].should == true
  end

  it "applies_baseline_profile_via_constructor_default" do
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

    pod_sc[:seccompProfile].should.be.nil
  end

  it "label_overrides_constructor_default" do
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

    pod_sc[:seccompProfile].should == { type: "RuntimeDefault" }
  end

  it "applies_to_all_containers" do
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

    containers.last.dig(:securityContext, :allowPrivilegeEscalation).should == false
  end

  it "skips_non_pod_bearing_resources" do
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "config" }
    m = manifest(resource)

    Middleware::SecurityContext.new.call(m)

    m.resources.first.to_h.should == resource.to_h
  end

  it "raises_on_unknown_profile" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/security": "yolo" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    lambda { Middleware::SecurityContext.new.call(m) }.should.raise ArgumentError
  end

  it "preserves_existing_pod_security_context" do
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
    pod_sc[:runAsUser].should == 9999
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
