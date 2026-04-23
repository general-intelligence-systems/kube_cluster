# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Middleware
      # Sets +metadata.namespace+ on all namespace-scoped resources.
      # Cluster-scoped kinds (Namespace, ClusterRole, etc.) are skipped.
      #
      #   stack do
      #     use Middleware::Namespace, "production"
      #   end
      #
      class Namespace < Middleware
        def initialize(namespace)
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! do |resource|
            next resource if resource.cluster_scoped?

            h = resource.to_h
            h[:metadata] ||= {}
            h[:metadata][:namespace] = @namespace
            resource.rebuild(h)
          end
        end
      end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  it "sets_namespace_on_configmap" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    Middleware::Namespace.new("production").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should == "production"
  end

  it "sets_namespace_on_deployment" do
    m = manifest(Kube::Cluster["Deployment"].new { metadata.name = "web" })

    Middleware::Namespace.new("staging").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should == "staging"
  end

  it "skips_namespace_resource" do
    m = manifest(Kube::Cluster["Namespace"].new { metadata.name = "my-ns" })

    Middleware::Namespace.new("production").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should.be.nil
  end

  it "skips_cluster_role" do
    m = manifest(Kube::Cluster["ClusterRole"].new { metadata.name = "admin" })

    Middleware::Namespace.new("production").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should.be.nil
  end

  it "skips_cluster_role_binding" do
    m = manifest(Kube::Cluster["ClusterRoleBinding"].new { metadata.name = "admin-binding" })

    Middleware::Namespace.new("production").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should.be.nil
  end

  it "overwrites_existing_namespace" do
    m = manifest(Kube::Cluster["ConfigMap"].new {
      metadata.name = "test"
      metadata.namespace = "old"
    })

    Middleware::Namespace.new("new").call(m)

    m.resources.first.to_h.dig(:metadata, :namespace).should == "new"
  end

  it "returns_new_resource_instance" do
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }
    m = manifest(resource)

    Middleware::Namespace.new("production").call(m)

    resource.equal?(m.resources.first).should.be.false
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
