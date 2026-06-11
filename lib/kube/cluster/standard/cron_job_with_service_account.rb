# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # A CronJob plus the ServiceAccount/Role/RoleBinding it runs as, bundled
      # into one Manifest. The RBAC rules use the Role shorthand; the CronJob's
      # serviceAccountName is wired to the generated ServiceAccount. Everything
      # is named after +name+.
      #
      #   CronJobWithServiceAccount.new(
      #     name:     "glauth-config-builder",
      #     image:    "nixery.dev/shell/ruby/kubectl/cacert",
      #     schedule: "*/5 * * * *",
      #     rules: [
      #       "secrets"        => %w[get list],
      #       "batch/jobs"     => %w[create],
      #     ],
      #     command: RubyScript(<<~'BUILD'),
      #       ...
      #     BUILD
      #   )
      #
      class CronJobWithServiceAccount < Kube::Cluster::Manifest
        def initialize(name:, image:, schedule:, rules:, env: {}, command: nil,
                       backoff_limit: 3, ttl: 300, concurrency_policy: "Forbid", &block)
          service_account_with_role = Kube::Cluster::Standard::ServiceAccountWithRole.new(
            service_account: Kube::Cluster::Standard::ServiceAccount.new(name: name),
            role: Kube::Cluster::Standard::Role.new(rules: rules),
          )

          cron_job = Kube::Cluster::Standard::CronJob.new(
            name: name,
            image: image,
            schedule: schedule,
            env: env,
            command: command,
            backoff_limit: backoff_limit,
            ttl: ttl,
            concurrency_policy: concurrency_policy,
          ) do
            spec.jobTemplate.spec.template.spec.serviceAccountName = name
          end

          super(*service_account_with_role.to_a, cron_job)

          instance_exec(&block) if block
        end
      end
    end
  end
end

test do
  describe "CronJobWithServiceAccount" do
    it "emits the RBAC trio plus the cron job" do
      m = Kube::Cluster::Standard::CronJobWithServiceAccount.new(
        name: "builder",
        image: "nixery.dev/shell/kubectl",
        schedule: "*/5 * * * *",
        rules: ["secrets" => %w[get list]],
        command: ["true"],
      )

      m.map { |r| r.to_h[:kind] }.sort.should == %w[CronJob Role RoleBinding ServiceAccount]
    end
  end
end
