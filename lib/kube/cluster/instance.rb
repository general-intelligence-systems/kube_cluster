# frozen_string_literal: true

module Kube
  module Cluster
    class Instance
      attr_reader :kubeconfig

      def initialize(kubeconfig:)
        @kubeconfig = kubeconfig
      end

      def connection
        @connection ||= Connection.new(kubeconfig: @kubeconfig)
      end

      def inspect
        "#<#{self.class.name} kubeconfig=#{@kubeconfig.inspect}>"
      end
    end
  end
end
