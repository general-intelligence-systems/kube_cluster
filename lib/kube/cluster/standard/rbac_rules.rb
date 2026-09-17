# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      # Builds Kubernetes RBAC PolicyRule arrays from a shorthand hash of
      # resource-spec => verbs. The spec is "resource" (core API group),
      # "resource/subresource" (core), "group/resource", or
      # "group/resource/subresource":
      #
      #   RbacRules.build(
      #     "secrets"               => %w[get list],
      #     "pods/log"              => %w[get],
      #     "batch/cronjobs"        => %w[get],
      #     "argoproj.io/workflows" => %w[get list],
      #     "subresources.kubevirt.io/virtualmachines/restart" => %w[create],
      #   )
      #
      # The first path segment is an API group when the schema knows it as
      # one (Kube::Schema.api_groups -- "batch", "apps", "argoproj.io", ...)
      # or when it contains a dot: API groups are DNS subdomains, so a dotted
      # segment is a group even when no schema has registered it (e.g. a CRD
      # group local to one cluster). Anything else is a core resource,
      # subresource included.
      module RbacRules
        def self.build(rules)
          entries = rules.is_a?(Hash) ? [rules] : Array(rules)

          entries.flat_map do |entry|
            entry.map do |spec, verbs|
              group, resource = split_spec(spec.to_s)
              { apiGroups: [group], resources: [resource], verbs: Array(verbs).map(&:to_s) }
            end
          end
        end

        def self.split_spec(spec)
          return ["", spec] unless spec.include?("/")

          first, rest = spec.split("/", 2)
          if Kube::Schema.api_groups.include?(first) || first.include?(".")
            [first, rest]
          else
            ["", spec]
          end
        end
      end
    end
  end
end

__END__

describe "RbacRules" do
  it "expands core resources into the empty group" do
    Kube::Cluster::Standard::RbacRules
      .build("secrets" => %w[get list])
      .should == [{ apiGroups: [""], resources: ["secrets"], verbs: %w[get list] }]
  end

  it "keeps core subresources with their resource" do
    Kube::Cluster::Standard::RbacRules
      .build("pods/log" => %w[get])
      .should == [{ apiGroups: [""], resources: ["pods/log"], verbs: %w[get] }]
  end

  it "splits groups the schema knows even without a dot (apps, batch)" do
    Kube::Cluster::Standard::RbacRules
      .build("batch/cronjobs" => %w[get], "apps/deployments" => %w[get])
      .should == [
        { apiGroups: ["batch"], resources: ["cronjobs"], verbs: %w[get] },
        { apiGroups: ["apps"],  resources: ["deployments"], verbs: %w[get] },
      ]
  end

  it "splits dotted groups" do
    Kube::Cluster::Standard::RbacRules
      .build("argoproj.io/workflows" => %w[get list])
      .should == [{ apiGroups: ["argoproj.io"], resources: ["workflows"], verbs: %w[get list] }]
  end

  it "keeps the subresource on grouped resources" do
    Kube::Cluster::Standard::RbacRules
      .build("subresources.kubevirt.io/virtualmachines/restart" => %w[create])
      .should == [{ apiGroups: ["subresources.kubevirt.io"], resources: ["virtualmachines/restart"], verbs: %w[create] }]
  end

  it "treats an unregistered dotted group as a group" do
    Kube::Cluster::Standard::RbacRules
      .build("tradeportal.ai/tenantvmclaims" => %w[get])
      .should == [{ apiGroups: ["tradeportal.ai"], resources: ["tenantvmclaims"], verbs: %w[get] }]
  end

  it "stringifies symbol verbs" do
    Kube::Cluster::Standard::RbacRules
      .build("secrets" => [:get, :list])
      .should == [{ apiGroups: [""], resources: ["secrets"], verbs: %w[get list] }]
  end

  it "accepts an array of hashes as well as a single hash" do
    Kube::Cluster::Standard::RbacRules
      .build([{ "secrets" => %w[get] }, { "pods" => %w[list] }])
      .should == [
        { apiGroups: [""], resources: ["secrets"], verbs: %w[get] },
        { apiGroups: [""], resources: ["pods"],    verbs: %w[list] },
      ]
  end
end
