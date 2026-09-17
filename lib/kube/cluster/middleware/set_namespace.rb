# frozen_string_literal: true

require "bundler/setup"
require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Sets +metadata.namespace+ on all namespace-scoped resources,
      # skipping HelmCharts and resources that already have a
      # non-default namespace set.
      #
      #   use SetNamespace, 'authelia'
      #
      class SetNamespace < Middleware
        def initialize(namespace)
          super(filter: ->(r) { r.kind != 'HelmChart' })
          @namespace = namespace
        end

        def call(manifest)
          manifest.resources.map! { |resource|
            filter(resource) {
              # A binding's ServiceAccount subjects need an explicit
              # namespace; fill in any left blank with the target namespace so
              # same-namespace bindings (e.g. ServiceAccountWithRole) resolve.
              # ClusterRoleBinding is cluster-scoped, so this runs before the
              # scope check below.
              if ['RoleBinding', 'ClusterRoleBinding'].include?(resource.kind)
                h = resource.to_h
                if h[:subjects].is_a?(Array)
                  filled = h[:subjects].map { |subject|
                    if subject[:kind] == 'ServiceAccount' &&
                       (subject[:namespace].nil? || subject[:namespace].to_s.empty?)
                      subject.merge(namespace: @namespace)
                    else
                      subject
                    end
                  }
                  if filled != h[:subjects]
                    h[:subjects] = filled
                    resource = resource.rebuild(h)
                  end
                end
              end

              next resource if resource.cluster_scoped?

              h = resource.to_h
              h[:metadata] ||= {}

              unless h[:metadata][:namespace] && h[:metadata][:namespace] != 'default'
                h[:metadata][:namespace] = @namespace
              end

              resource.rebuild(h)
            }
          }
        end
      end
    end
  end
end

__END__

Middleware = Kube::Cluster::Middleware

it "sets the namespace on namespaced resources" do
  m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

  Middleware::SetNamespace.new("production").call(m)

  m.resources.first.to_h.dig(:metadata, :namespace).should == "production"
end

it "fills blank ServiceAccount subject namespaces on RoleBinding" do
  m = manifest(Kube::Cluster["RoleBinding"].new {
    metadata.name = "rb"
    self.roleRef  = { apiGroup: "rbac.authorization.k8s.io", kind: "Role", name: "r" }
    self.subjects = [{ kind: "ServiceAccount", name: "sa" }]
  })

  Middleware::SetNamespace.new("production").call(m)
  rb = m.resources.first.to_h

  rb.dig(:subjects, 0, :namespace).should == "production"
  rb.dig(:metadata, :namespace).should == "production"
end

it "fills blank ServiceAccount subject namespaces on cluster-scoped ClusterRoleBinding" do
  m = manifest(Kube::Cluster["ClusterRoleBinding"].new {
    metadata.name = "crb"
    self.roleRef  = { apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "cr" }
    self.subjects = [{ kind: "ServiceAccount", name: "sa" }]
  })

  Middleware::SetNamespace.new("production").call(m)
  crb = m.resources.first.to_h

  crb.dig(:subjects, 0, :namespace).should == "production"
  crb.dig(:metadata, :namespace).should.be.nil
end

it "leaves pre-set subject namespaces alone" do
  m = manifest(Kube::Cluster["ClusterRoleBinding"].new {
    metadata.name = "crb"
    self.roleRef  = { apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "cr" }
    self.subjects = [{ kind: "ServiceAccount", name: "sa", namespace: "other" }]
  })

  Middleware::SetNamespace.new("production").call(m)

  m.resources.first.to_h.dig(:subjects, 0, :namespace).should == "other"
end

private

  def manifest(*resources)
    m = Kube::Cluster::Manifest.new
    resources.each { |r| m << r }
    m
  end
