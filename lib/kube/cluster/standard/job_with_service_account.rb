# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # A one-shot Job plus the ServiceAccount/Role/RoleBinding it runs as,
      # bundled into one Manifest. The RBAC rules use the Role shorthand; the
      # Job's serviceAccountName is wired to the generated ServiceAccount.
      # Everything is named after +name+.
      #
      #   JobWithServiceAccount.new(
      #     name:  "glauth-config-seed",
      #     image: "nixery.dev/shell/kubectl",
      #     rules: [
      #       "batch/cronjobs" => %w[get],
      #       "batch/jobs"     => %w[create],
      #     ],
      #     command: BashScript(<<~'SEED'),
      #       ...
      #     SEED
      #   )
      #
      class JobWithServiceAccount < Kube::Cluster::Manifest
        def initialize(name:, image:, rules:, env: {}, command: nil,
                       backoff_limit: 3, ttl: 300, &block)
          service_account_with_role = Kube::Cluster::Standard::ServiceAccountWithRole.new(
            service_account: Kube::Cluster::Standard::ServiceAccount.new(name: name),
            role: Kube::Cluster::Standard::Role.new(rules: rules),
          )

          job = Kube::Cluster::Standard::Job.new(
            name: name,
            image: image,
            env: env,
            command: command,
            backoff_limit: backoff_limit,
            ttl: ttl,
          ) do
            spec.template.spec.serviceAccountName = name
          end

          super(*service_account_with_role.to_a, job)

          instance_exec(&block) if block
        end
      end
    end
  end
end

__END__

describe "JobWithServiceAccount" do
  it "emits the RBAC trio plus the job" do
    m = Kube::Cluster::Standard::JobWithServiceAccount.new(
      name: "seed",
      image: "nixery.dev/shell/kubectl",
      rules: ["batch/jobs" => %w[create]],
      command: ["true"],
    )

    m.map { |r| r.to_h[:kind] }.sort.should == %w[Job Role RoleBinding ServiceAccount]
  end
end
