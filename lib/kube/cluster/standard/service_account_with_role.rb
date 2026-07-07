# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # Bundles a ServiceAccount, a Role, and the RoleBinding that ties them
      # together into one Manifest. The Role and RoleBinding take the
      # ServiceAccount's name unless a name is given explicitly:
      #
      #   ServiceAccountWithRole.new(
      #     service_account: ServiceAccount.new(name: "glauth-config-builder"),
      #     role: Role.new(rules: [
      #       "secrets"        => %w[get list],
      #       "batch/cronjobs" => %w[get],
      #     ]),
      #   )
      #
      class ServiceAccountWithRole < Kube::Cluster::Manifest
        def initialize(service_account:, role:, name: nil, &block)
          name ||= service_account.name

          # Rebuild the Role with the derived name (a Standard::Role, so the
          # binding's role.name reader works).
          named_role = Kube::Cluster::Standard::Role.new(name: name, rules: role.rules_input)

          role_binding = Kube::Cluster::Standard::RoleBinding.new(
            role: named_role,
            service_account: service_account,
            name: name,
          )

          super(service_account, named_role, role_binding)

          instance_exec(&block) if block
        end
      end
    end
  end
end

__END__

describe "ServiceAccountWithRole" do
  it "emits the service account, role, and binding" do
    m = Kube::Cluster::Standard::ServiceAccountWithRole.new(
      service_account: Kube::Cluster::Standard::ServiceAccount.new(name: "sa"),
      role: Kube::Cluster::Standard::Role.new(rules: ["secrets" => %w[get list]]),
    )

    m.map { |r| r.to_h[:kind] }.sort.should == %w[Role RoleBinding ServiceAccount]
  end
end
