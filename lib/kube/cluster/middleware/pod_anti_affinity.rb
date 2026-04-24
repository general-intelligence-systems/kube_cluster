# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Middleware
      # Injects soft pod anti-affinity on pod-bearing resources so
      # that pods prefer to spread across nodes.
      #
      # The anti-affinity uses the resource's own +matchLabels+ from
      # +spec.selector.matchLabels+ as the label selector, and
      # +kubernetes.io/hostname+ as the topology key.
      #
      # Resources that already have +spec.template.spec.affinity+
      # set are left untouched.
      #
      #   stack do
      #     use Middleware::PodAntiAffinity
      #     use Middleware::PodAntiAffinity, topology_key: "topology.kubernetes.io/zone"
      #   end
      #
      class PodAntiAffinity < Middleware
        def call(manifest)
          topology_key = @opts.fetch(:topology_key, "kubernetes.io/hostname")
          weight = @opts.fetch(:weight, 1)

          manifest.resources.map! do |resource|
            filter(resource) do
              next resource unless resource.pod_bearing?

              h = resource.to_h
              pod_spec = resource.pod_template(h)
              next resource unless pod_spec

              # Don't overwrite existing affinity configuration.
              next resource if pod_spec[:affinity]

              match_labels = h.dig(:spec, :selector, :matchLabels)
              next resource unless match_labels && !match_labels.empty?

              pod_spec[:affinity] = {
                podAntiAffinity: {
                  preferredDuringSchedulingIgnoredDuringExecution: [
                    {
                      weight: weight,
                      podAffinityTerm: {
                        labelSelector: { matchLabels: match_labels },
                        topologyKey: topology_key,
                      },
                    },
                  ],
                },
              }

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

  it "injects_soft_anti_affinity_on_deployment" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web", instance: "prod" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    Middleware::PodAntiAffinity.new.call(m)
    affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

    paa = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution)
    paa.size.should == 1
  end

  it "custom_topology_key" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    Middleware::PodAntiAffinity.new(
      topology_key: "topology.kubernetes.io/zone",
    ).call(m)

    affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)
    term = affinity.dig(:podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

    term.dig(:podAffinityTerm, :topologyKey).should == "topology.kubernetes.io/zone"
  end

  it "custom_weight" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    Middleware::PodAntiAffinity.new(weight: 100).call(m)
    term = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity,
      :podAntiAffinity, :preferredDuringSchedulingIgnoredDuringExecution, 0)

    term[:weight].should == 100
  end

  it "skips_resources_with_existing_affinity" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.affinity = { nodeAffinity: { custom: true } }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    Middleware::PodAntiAffinity.new.call(m)
    affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

    affinity.should == { nodeAffinity: { custom: true } }
  end

  it "skips_non_pod_bearing_resources" do
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "config" }
    m = manifest(resource)

    Middleware::PodAntiAffinity.new.call(m)

    m.resources.first.to_h.should == resource.to_h
  end

  it "skips_resources_without_match_labels" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx:latest" },
      ]
    })

    Middleware::PodAntiAffinity.new.call(m)
    affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

    affinity.should.be.nil
  end

  it "applies_to_statefulset" do
    m = manifest(Kube::Cluster["StatefulSet"].new {
      metadata.name = "db"
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16" },
      ]
    })

    Middleware::PodAntiAffinity.new.call(m)
    affinity = m.resources.first.to_h.dig(:spec, :template, :spec, :affinity)

    affinity.dig(:podAntiAffinity).should.not.be.nil
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
