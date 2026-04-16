# frozen_string_literal: true

module Kube
  module Cluster
    class CommandNode
      include Enumerable

      BLANK_DATA = { commands: [], resource: nil, args: [], flags: {} }.freeze

      attr_reader :command_data

      def initialize(current_node:, command_data: BLANK_DATA)
        @current_node = current_node
        @command_data = command_data
      end

      def flag(key, value = nil)
        self.class.new(
          current_node: @current_node,
          command_data: @command_data.merge(
            flags: @command_data[:flags].merge(key.to_s.tr("_", "-") => value)
          )
        )
      end

      def each(&block)
        to_a.each(&block)
      end

      def to_a
        QueryBuilder.new(@command_data).to_a
      end

      def to_s
        QueryBuilder.new(@command_data).to_s
      end

      def inspect
        "#<#{self.class.name} #{to_s}>"
      end

      def method_missing(name, *args, &block)
        segment = name.to_s.tr("_", "-")
        child   = @current_node.children[segment]

        if child&.command?
          self.class.new(
            current_node: child,
            command_data: @command_data.merge(
              commands: @command_data[:commands] + [segment],
              args:     @command_data[:args] + args.map(&:to_s)
            )
          )
        elsif child&.resource?
          self.class.new(
            current_node: child,
            command_data: @command_data.merge(
              resource: (@command_data[:resource] || ResourceSelector.new) + [segment],
              args:     @command_data[:args] + args.map(&:to_s)
            )
          )
        elsif @current_node.resource? || @current_node.children.empty?
          # Leaf command or already in resource mode — free-form resource segment
          self.class.new(
            current_node: TreeNode.new(name: segment, type: :resource),
            command_data: @command_data.merge(
              resource: (@command_data[:resource] || ResourceSelector.new) + [segment],
              args:     @command_data[:args] + args.map(&:to_s)
            )
          )
        elsif Enumerable.method_defined?(name)
          to_a.public_send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        segment = name.to_s.tr("_", "-")

        @current_node.children.key?(segment) ||
          @current_node.resource? ||
          @current_node.children.empty? ||
          Enumerable.method_defined?(name) ||
          super
      end
    end
  end
end
