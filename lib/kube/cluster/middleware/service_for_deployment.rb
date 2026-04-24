# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Middleware
      # Generates a Service for every pod-bearing resource that has
      # containers with named ports.
      #
      # The generated Service uses +spec.selector.matchLabels+ from
      # the source resource and maps each named container port.
      #
      # Labels and namespace are copied from the source resource, so
      # subsequent middleware (Labels, Namespace, etc.) will also
      # apply to the generated Service.
      #
      #   stack do
      #     use Middleware::ServiceForDeployment
      #   end
      #
      class ServiceForDeployment < Middleware
        def call(manifest)
          generated = []

          manifest.resources.each do |resource|
            filter(resource) do
              next unless resource.pod_bearing?

              h = resource.to_h
              ports = extract_ports(resource, h)
              next if ports.empty?

              match_labels = h.dig(:spec, :selector, :matchLabels)
              next unless match_labels && !match_labels.empty?

              generated << Kube::Cluster["Service"].new {
                metadata.name      = h.dig(:metadata, :name)
                metadata.namespace = h.dig(:metadata, :namespace) if h.dig(:metadata, :namespace)
                metadata.labels    = h.dig(:metadata, :labels) || {}

                spec.selector = match_labels
                spec.ports = ports.map { |p|
                  {
                    name:       p[:name],
                    port:       p[:containerPort],
                    targetPort: p[:name],
                    protocol:   p.fetch(:protocol, "TCP"),
                  }
                }
              }
            end
          end

          manifest.resources.concat(generated)
        end

        private

          def extract_ports(resource, hash)
            pod_spec = resource.pod_template(hash)
            return [] unless pod_spec

            ports = []
            resource.each_container(pod_spec) do |container|
              Array(container[:ports]).each do |port|
                ports << port if port[:name]
              end
            end
            ports
          end
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  it "generates_service_from_deployment" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "production"
      metadata.labels = { app: "web" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080, protocol: "TCP" }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    deploy, service = m.resources
    sh = service.to_h
    port = sh.dig(:spec, :ports, 0)

    port[:protocol].should == "TCP"
  end

  it "maps_multiple_ports" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        {
          name: "web", image: "nginx",
          ports: [
            { name: "http", containerPort: 8080 },
            { name: "metrics", containerPort: 9090 },
          ],
        },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)
    service = m.resources.last
    ports = service.to_h.dig(:spec, :ports)

    ports.size.should == 2
  end

  it "copies_labels_from_source" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.labels = { "app.kubernetes.io/name": "web", "app.kubernetes.io/size": "small" }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)
    service_labels = m.resources.last.to_h.dig(:metadata, :labels)

    service_labels[:"app.kubernetes.io/size"].should == "small"
  end

  it "skips_deployment_without_named_ports" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    m.resources.size.should == 1
  end

  it "skips_deployment_without_ports" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "worker"
      spec.selector.matchLabels = { app: "worker" }
      spec.template.metadata.labels = { app: "worker" }
      spec.template.spec.containers = [
        { name: "worker", image: "worker:latest" },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    m.resources.size.should == 1
  end

  it "skips_non_pod_bearing_resources" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "config" })

    Middleware::ServiceForDeployment.new.call(m)

    m.resources.size.should == 1
  end

  it "skips_deployment_without_match_labels" do
    m = manifest(Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    m.resources.size.should == 1
  end

  it "works_with_statefulset" do
    m = manifest(Kube::Cluster["StatefulSet"].new {
      metadata.name = "db"
      metadata.namespace = "database"
      spec.selector.matchLabels = { app: "db" }
      spec.template.metadata.labels = { app: "db" }
      spec.template.spec.containers = [
        { name: "postgres", image: "postgres:16", ports: [{ name: "tcp-pg", containerPort: 5432 }] },
      ]
    })

    Middleware::ServiceForDeployment.new.call(m)

    m.resources.last.to_h.dig(:metadata, :namespace).should == "database"
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
