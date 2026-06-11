# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"
require "kube/cluster/standard/env_processing"

module Kube
  module Cluster
    module Standard
      class CronJob < Kube::Cluster["CronJob"]
        def initialize(name:, image:, schedule:, env: {}, command: nil,
                       backoff_limit: 3, ttl: 300, concurrency_policy: "Forbid", &block)
          processed_env = EnvProcessing.process(env)

          super() do
            metadata.name = name

            spec.schedule = schedule
            spec.concurrencyPolicy = concurrency_policy

            spec.jobTemplate.spec.backoffLimit = backoff_limit
            spec.jobTemplate.spec.ttlSecondsAfterFinished = ttl
            spec.jobTemplate.spec.template.spec.restartPolicy = "OnFailure"

            container = {
              name: name,
              image: image,
              env: processed_env
            }
            container[:command] = command if command

            spec.jobTemplate.spec.template.spec.containers = [container]

            instance_exec(&block) if block
          end
        end
      end
    end
  end
end

test do
  describe "CronJob" do
    it "initializes without error" do
      Kube::Cluster::Standard::CronJob
        .new(
          name: "my-cron",
          image: "nixery.dev/shell/kubectl",
          schedule: "*/5 * * * *",
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
