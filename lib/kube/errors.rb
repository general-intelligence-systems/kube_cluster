# frozen_string_literal: true

# This file defines cluster-specific errors in the Kube namespace.

module Kube
  # Base error class for the Kube namespace.
  class Error < StandardError; end
  # Raised when a kubectl command fails.
  #
  #   begin
  #     resource.patch
  #   rescue Kube::CommandError => e
  #     e.subcommand  # => "patch"
  #     e.stderr      # => "Error from server (NotFound): ..."
  #     e.exit_code   # => 1
  #     e.reason      # => "NotFound"  (parsed from stderr, or nil)
  #   end
  #
  class CommandError < Error
    attr_reader :subcommand, :stderr, :exit_code, :reason

    def initialize(message = nil, subcommand: nil, stderr: nil, exit_code: nil, reason: nil)
      @subcommand = subcommand
      @stderr     = stderr
      @exit_code  = exit_code
      @reason     = reason || parse_reason(stderr)
      super(message || build_message)
    end

    def self.from_kubectl(subcommand:, stderr:, exit_code:)
      new(
        subcommand: subcommand,
        stderr: stderr,
        exit_code: exit_code
      )
    end

    private

      def build_message
        "kubectl #{@subcommand} failed (exit #{@exit_code}): #{@stderr}"
      end

      # Attempts to extract the reason from kubectl stderr.
      # kubectl errors typically look like:
      #   Error from server (NotFound): deployments.apps "foo" not found
      #   Error from server (Forbidden): ...
      #   error: the server doesn't have a resource type "foo"
      def parse_reason(stderr)
        return nil if stderr.nil? || stderr.empty?

        if stderr =~ /\((\w+)\)/
          $1
        end
      end
  end
end
