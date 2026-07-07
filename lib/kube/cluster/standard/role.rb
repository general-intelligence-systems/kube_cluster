# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # A Role with an ergonomic rules shorthand. Each rule maps a resource
      # spec to its verbs; the spec is "resource" (core API group) or
      # "group/resource":
      #
      #   Role.new(rules: [
      #     "secrets"        => %w[get list],
      #     "batch/cronjobs" => %w[get],
      #   ])
      #
      class Role < Kube::Cluster["Role"]
        # The original rules shorthand, so a named copy can be rebuilt from it
        # (rebuild downgrades the class; reconstructing keeps it a Standard::Role).
        attr_reader :rules_input

        def initialize(rules:, name: nil, &block)
          @rules_input = rules

          super() do
            metadata.name = name if name
            self.rules = Role.build_rules(rules)
            instance_exec(&block) if block
          end
        end

        def name
          to_h.dig(:metadata, :name)
        end

        def self.build_rules(rules)
          entries = rules.is_a?(Hash) ? [rules] : Array(rules)

          entries.flat_map do |entry|
            entry.map do |spec, verbs|
              group, resource = spec.include?("/") ? spec.split("/", 2) : ["", spec]
              { apiGroups: [group], resources: [resource], verbs: Array(verbs) }
            end
          end
        end
      end
    end
  end
end

__END__

describe "Role" do
  it "expands the rules shorthand" do
    yaml = Kube::Cluster::Standard::Role
      .new(name: "r", rules: [
        "secrets"        => %w[get list],
        "batch/cronjobs" => %w[get],
      ])
      .to_yaml

    yaml.include?("resources").should == true
    yaml.include?("batch").should == true
  end
end
