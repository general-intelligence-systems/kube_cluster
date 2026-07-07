# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # A RoleBinding that wires a Role to a ServiceAccount. This is just the
      # binding resource -- the Role and ServiceAccount are defined separately
      # (and emitted together by ServiceAccountWithRole):
      #
      #   RoleBinding.new(role: MyRole, service_account: MyServiceAccount)
      #
      # The subject namespace is left blank when the ServiceAccount has none, so
      # the SetNamespace middleware fills it with the target namespace.
      class RoleBinding < Kube::Cluster["RoleBinding"]
        def initialize(role:, service_account:, name: nil, &block)
          name ||= role.name || service_account.name
          role_name = role.name || name

          subject = { kind: "ServiceAccount", name: service_account.name }
          subject[:namespace] = service_account.namespace if service_account.namespace

          super() do
            metadata.name = name
            self.roleRef = {
              apiGroup: "rbac.authorization.k8s.io",
              kind: "Role",
              name: role_name,
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

describe "RoleBinding" do
  it "references the role and service account" do
    yaml = Kube::Cluster::Standard::RoleBinding.new(
      role: Kube::Cluster::Standard::Role.new(name: "r", rules: ["secrets" => %w[get]]),
      service_account: Kube::Cluster::Standard::ServiceAccount.new(name: "sa"),
    ).to_yaml

    yaml.include?("name: r").should == true
    yaml.include?("name: sa").should == true
  end
end
