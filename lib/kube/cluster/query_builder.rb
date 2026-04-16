# frozen_string_literal: true

require "open3"

module Kube
  module Cluster
    class QueryBuilder
      def initialize(command_data)
        @commands = command_data[:commands] || []
        @resource = command_data[:resource]
        @args     = command_data[:args] || []
        @flags    = command_data[:flags] || {}
      end

      def to_s
        ["kubectl", *@commands, *resource_arg, *@args, *rendered_flags].join(" ")
      end

      def to_a
        stdout, _status = Open3.capture2("kubectl", *@commands, *resource_arg, *@args, *rendered_flags)
        stdout.lines.map(&:chomp)
      end

      private

      def resource_arg
        @resource ? [@resource.to_s] : []
      end

      def rendered_flags
        @flags.flat_map { |k, v| v.nil? ? ["--#{k}"] : ["--#{k}", v.to_s] }
      end
    end
  end
end
