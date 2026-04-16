# frozen_string_literal: true

module Kube
  module Cluster
    class TreeNode
      # Commands whose leaf children are resource types.
      # Non-leaf children (those with their own subtree) remain commands.
      RESOURCE_PARENTS = %w[
        create
        create/secret
        create/service
        top
      ].freeze

      attr_reader :name, :type, :children

      def initialize(name:, type:, children: {})
        @name     = name.freeze
        @type     = type
        @children = children.freeze
      end

      def command?  = type == :command
      def resource? = type == :resource

      # Recursively build a children hash of TreeNodes from the parsed JSON.
      # parent_path tracks position in the tree to determine child types.
      def self.build(hash, parent_path: nil)
        hash.each_with_object({}) do |(key, subtree), children|
          name         = key.to_s
          current_path = [parent_path, name].compact.join("/")
          leaf         = subtree.empty?

          # Under a resource parent, leaf nodes are resources, non-leaves are commands.
          # Everywhere else, everything is a command.
          child_type = if RESOURCE_PARENTS.include?(parent_path.to_s) && leaf
                         :resource
                       else
                         :command
                       end

          children[name] = new(
            name:     name,
            type:     child_type,
            children: build(subtree, parent_path: current_path)
          )
        end
      end
    end
  end
end
