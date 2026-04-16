# frozen_string_literal: true

require "json"

module Kube
  module Cluster
    class Ctl
      GEM_ROOT = File.expand_path("../../..", __dir__)

      COMMAND_TREE = JSON.parse(
        File.read(File.join(GEM_ROOT, "data", "kubectl-command-tree-v1-minimal.json"))
      )

      ROOT = TreeNode.new(
        name:     "kubectl",
        type:     :command,
        children: TreeNode.build(COMMAND_TREE)
      )

      def method_missing(name, *args, &block)
        CommandNode.new(current_node: ROOT).public_send(name, *args, &block)
      end

      def respond_to_missing?(name, include_private = false)
        CommandNode.new(current_node: ROOT).respond_to?(name) || super
      end

      def inspect
        "#<#{self.class.name}>"
      end
    end
  end
end
