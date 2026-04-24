# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    # A flat, ordered collection of Kubernetes resources.
    #
    # Manifest is a pure resource collection. Middleware is applied
    # separately via Kube::Cluster::Middleware::Stack.
    #
    #   manifest = Kube::Cluster::Manifest.new
    #   manifest << Kube::Cluster["Deployment"].new { ... }
    #
    #   stack = Kube::Cluster::Middleware::Stack.new do
    #     use Middleware::Namespace, "production"
    #     use Middleware::Labels, app: "web-app"
    #   end
    #
    #   stack.call(manifest)
    #   manifest.to_yaml
    #
    class Manifest < Kube::Schema::Manifest
      attr_reader :resources

      # Override << to automatically upgrade Kube::Schema::Resource
      # instances into Kube::Cluster::Resource instances. This ensures
      # resources parsed via Kube::Schema::Manifest (e.g. from Helm
      # charts or downloaded YAML) gain cluster-level methods like
      # cluster_scoped?, pod_bearing?, and rebuild when composed into
      # a cluster manifest.
      def <<(item)
        case item
        when Kube::Cluster::Resource
          @resources << item
        when Kube::Schema::Resource
          @resources << Kube::Cluster[item.kind].new(item.to_h)
        when Kube::Schema::Manifest
          item.each { |r| self << r }
        when Array
          item.each { |r| self << r }
        else
          raise ArgumentError,
            "Expected a Kube::Schema::Resource or Manifest, got #{item.class}. " \
            "Use Kube::Schema.parse(hash) to convert hashes."
        end

        self
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  # ── Bare manifest ────────────────────────────────────────────────────────

  it "bare_manifest_enumerates_resources_unchanged" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      self.data = { key: "value" }
    }

    resources = m.to_a
    resources.size.should == 1
  end

  # ── Stack transforms resources ───────────────────────────────────────────

  it "stack_transforms_resources" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
    }

    stack = Middleware::Stack.new do
      use Middleware::Namespace, "production"
    end
    stack.call(m)

    resources = m.to_a
    resources.first.to_h.dig(:metadata, :namespace).should == "production"
  end

  it "to_yaml_reflects_middleware" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
    }

    Middleware::Namespace.new("production").call(m)

    yaml = m.to_yaml
    yaml.should.include "namespace: production"
  end

  it "enumerable_methods_work" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new { metadata.name = "a" }
    m << Kube::Cluster["ConfigMap"].new { metadata.name = "b" }

    Middleware::Namespace.new("production").call(m)

    names = m.map { |r| r.to_h.dig(:metadata, :name) }
    names.should == %w[a b]
  end

  # ── Multi-middleware stack ──────────────────────────────────────────────

  it "multiple_middleware_compose_in_order" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
    }

    stack = Middleware::Stack.new do
      use Middleware::Namespace, "staging"
      use Middleware::Labels, app: "myapp", managed_by: "kube_cluster"
    end
    stack.call(m)

    r = m.first
    h = r.to_h

    h.dig(:metadata, :namespace).should == "staging"
  end

  # ── size reflects resource count ─────────────────────────────────────────

  it "size_reflects_resource_count" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new { metadata.name = "a" }
    m << Kube::Cluster["ConfigMap"].new { metadata.name = "b" }

    m.size.should == 2
  end

  # ── each without block ──────────────────────────────────────────────────

  it "each_without_block_returns_enumerator" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    Middleware::Namespace.new("production").call(m)

    enum = m.each
    enum.should.be.instance_of Enumerator
  end

  # ── Generative middleware produces new resources ─────────────────────────

  it "generative_middleware_adds_service" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "default"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    Middleware::ServiceForDeployment.new.call(m)

    kinds = m.map { |r| r.to_h[:kind] }
    kinds.should == %w[Deployment Service]
  end

  it "generative_middleware_does_not_affect_non_matching_resources" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["ConfigMap"].new {
      metadata.name = "config"
    }

    Middleware::ServiceForDeployment.new.call(m)

    resources = m.to_a
    resources.size.should == 1
  end

  # ── Generated resources flow through subsequent middleware stages ────────

  it "generated_resources_flow_through_subsequent_stages" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    stack = Middleware::Stack.new do
      use Middleware::ServiceForDeployment           # generates Service
      use Middleware::Namespace, "production"         # namespaces everything
      use Middleware::Labels, managed_by: "middleware" # labels everything
    end
    stack.call(m)

    resources = m.to_a
    resources.size.should == 2
  end

  # ── YAML serializes integers correctly ──────────────────────────────────

  it "to_yaml_serializes_integers_as_plain_values" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    yaml = m.to_yaml
    yaml.should.include "containerPort: 8080"
  end

  # ── Multi-generative: chained generation ────────────────────────────────

  it "chained_generative_middleware" do
    m = Kube::Cluster::Manifest.new
    m << Kube::Cluster["Deployment"].new {
      metadata.name = "web"
      metadata.namespace = "default"
      metadata.labels = {
        "app.kubernetes.io/expose":    "app.example.com",
        "app.kubernetes.io/autoscale": "2-10",
      }
      spec.selector.matchLabels = { app: "web" }
      spec.template.metadata.labels = { app: "web" }
      spec.template.spec.containers = [
        { name: "web", image: "nginx", ports: [{ name: "http", containerPort: 8080 }] },
      ]
    }

    stack = Middleware::Stack.new do
      use Middleware::ServiceForDeployment   # Deployment → +Service
      use Middleware::IngressForService       # Service with expose label → +Ingress
      use Middleware::HPAForDeployment        # Deployment with autoscale label → +HPA
    end
    stack.call(m)

    kinds = m.map { |r| r.to_h[:kind] }

    m.to_a.size.should == 4
  end
end
