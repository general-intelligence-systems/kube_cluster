# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module VictoriaMetrics
        # A recording rule. The block returns the PromQL expression, so
        # multi-line queries read as a heredoc at the call site.
        class Rule
          def initialize(name, labels: nil, &block)
            @name   = name
            @labels = labels
            @expr   = block.call.to_s if block
          end

          def to_h
            h = { record: @name, expr: @expr }
            h[:labels] = @labels if @labels
            h
          end
        end

        # An alerting rule. The block returns the PromQL expression.
        class Alert
          def initialize(name, for_: nil, keep_firing_for: nil, labels: nil, annotations: nil, &block)
            @name            = name
            @for             = for_
            @keep_firing_for = keep_firing_for
            @labels          = labels
            @annotations     = annotations
            @expr            = block.call.to_s if block
          end

          def to_h
            h = { alert: @name, expr: @expr }
            h[:for]             = @for             if @for
            h[:keep_firing_for] = @keep_firing_for if @keep_firing_for
            h[:labels]          = @labels          if @labels
            h[:annotations]     = @annotations     if @annotations
            h
          end
        end

        # A named group of rules. `rule`/`alert` build and collect the leaves;
        # the block is instance_eval'd so those helpers read like keywords.
        #
        #   Group.new("node.rules") {
        #     rule "node:node_num_cpu:sum" do
        #       <<~PROMQL
        #         count by (cluster, node) (...)
        #       PROMQL
        #     end
        #   }
        class Group
          def initialize(name, &block)
            @name  = name
            @rules = []
            instance_eval(&block) if block
          end

          def rule(name, **opts, &block)  = @rules << Rule.new(name, **opts, &block)
          def alert(name, **opts, &block) = @rules << Alert.new(name, **opts, &block)

          def to_h = { name: @name, rules: @rules.map(&:to_h) }
        end

        # A VMRule CR: a set of rule Groups evaluated by VictoriaMetrics.
        #
        #   VMRule.new(name: "node", groups: [
        #     Group.new("node.rules") { ... },
        #   ])
        class VMRule < Kube::Cluster["VMRule"]
          def initialize(name:, groups:, &block)
            super() {
              metadata.name = name
              spec.groups   = groups.map(&:to_h)
              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "VictoriaMetrics::VMRule" do
  vmrule = Kube::Cluster::Standard::VictoriaMetrics::VMRule
  group  = Kube::Cluster::Standard::VictoriaMetrics::Group

  it "emits a recording rule with the resolved v1beta1 apiVersion" do
    yaml = vmrule.new(
      name:   "node",
      groups: [
        group.new("node.rules") {
          rule "node:node_num_cpu:sum" do
            "count by (cluster, node) (node_cpu_seconds_total)"
          end
        },
      ]
    ).to_yaml

    yaml.include?("operator.victoriametrics.com/v1beta1").should == true
    yaml.include?("record: node:node_num_cpu:sum").should == true
  end

  it "carries labels on records" do
    group.new("g") {
      rule "r", labels: { quantile: "0.99" } do
        "histogram_quantile(0.99, x)"
      end
    }.to_h.should == {
      name:  "g",
      rules: [{ record: "r", expr: "histogram_quantile(0.99, x)", labels: { quantile: "0.99" } }],
    }
  end

  it "builds alerts with for/labels/annotations" do
    group.new("g") {
      alert "Down", for_: "5m", labels: { severity: "warning" }, annotations: { summary: "down" } do
        "up == 0"
      end
    }.to_h.should == {
      name:  "g",
      rules: [{
        alert:       "Down",
        expr:        "up == 0",
        for:         "5m",
        labels:      { severity: "warning" },
        annotations: { summary: "down" },
      }],
    }
  end
end
