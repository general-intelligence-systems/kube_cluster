# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"
require "kube/cluster/standard/rbac_rules"

module Kube
  module Cluster
    module Standard
      # A ClusterRole with the same rules shorthand as Role (see RbacRules):
      #
      #   ClusterRole.new(name: "node-reader", rules: {
      #     "nodes"                 => %w[get list],
      #     "nodes/proxy"           => %w[get],
      #     "argoproj.io/workflows" => %w[get list],
      #   })
      #
      class ClusterRole < Kube::Cluster["ClusterRole"]
        # The original rules shorthand, so a named copy can be rebuilt from it
        # (rebuild downgrades the class; reconstructing keeps it a
        # Standard::ClusterRole).
        attr_reader :rules_input

        def initialize(rules:, name: nil, &block)
          @rules_input = rules

          super() do
            metadata.name = name if name
            self.rules = RbacRules.build(rules)
            instance_exec(&block) if block
          end
        end

        def name
          to_h.dig(:metadata, :name)
        end
      end
    end
  end
end

__END__

describe "ClusterRole" do
  it "expands the rules shorthand" do
    yaml = Kube::Cluster::Standard::ClusterRole
      .new(name: "r", rules: {
        "namespaces"              => %w[get list],
        "pods/log"                => %w[get],
        "argoproj.io/workflows"   => %w[get list],
        "batch/cronjobs"          => %w[get],
      })
      .to_yaml

    yaml.include?("kind: ClusterRole").should == true
    yaml.include?("- namespaces").should == true
    yaml.include?("- pods/log").should == true
    yaml.include?("- argoproj.io").should == true
    yaml.include?("- batch").should == true
  end

  it "renders core subresources in the core group (not as apiGroups: [pods])" do
    rules = Kube::Cluster::Standard::ClusterRole
      .new(name: "r", rules: { "pods/exec" => %w[create] })
      .to_h[:rules]

    rules.should == [{ apiGroups: [""], resources: ["pods/exec"], verbs: %w[create] }]
  end
end
