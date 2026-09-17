# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # A ClusterRoleBinding that wires a ClusterRole to a ServiceAccount.
      # Mirrors RoleBinding:
      #
      #   ClusterRoleBinding.new(role: MyClusterRole, service_account: MyServiceAccount)
      #
      # The subject namespace comes from the ServiceAccount when it has one,
      # and is otherwise left blank for the SetNamespace middleware to fill --
      # ClusterRoleBinding is cluster-scoped, so there is no metadata.namespace
      # to copy from, but the middleware fills binding subjects directly.
      class ClusterRoleBinding < Kube::Cluster["ClusterRoleBinding"]
        def initialize(role:, service_account:, name: nil, &block)
          name ||= role.name || service_account.name
          role_name = role.name || name

          subject = { kind: "ServiceAccount", name: service_account.name }
          subject[:namespace] = service_account.namespace if service_account.namespace

          super() do
            metadata.name = name
            self.roleRef = {
              apiGroup: "rbac.authorization.k8s.io",
              kind:     "ClusterRole",
              name:     role_name,
            }
            self.subjects = [subject]
            instance_exec(&block) if block
          end
        end
      end
    end
  end
end

__END__

describe "ClusterRoleBinding" do
  it "references the cluster role and service account" do
    yaml = Kube::Cluster::Standard::ClusterRoleBinding.new(
      role: Kube::Cluster::Standard::ClusterRole.new(name: "cr", rules: { "nodes" => %w[get] }),
      service_account: Kube::Cluster::Standard::ServiceAccount.new(name: "sa"),
    ).to_yaml

    yaml.include?("kind: ClusterRoleBinding").should == true
    yaml.include?("kind: ClusterRole").should == true
    yaml.include?("name: cr").should == true
    yaml.include?("name: sa").should == true
  end
end
