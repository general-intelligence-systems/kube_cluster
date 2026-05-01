# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Connection
      attr_reader :kubeconfig, :ctl, :helm

      def initialize(kubeconfig:)
        @kubeconfig = kubeconfig
        @ctl        = Kube::Ctl::Instance.new(kubeconfig: kubeconfig)
        @helm       = Kube::Helm::Instance.new(kubeconfig: kubeconfig)
      end

      def inspect
        "#<#{self.class.name} kubeconfig=#{@kubeconfig.inspect}>"
      end
    end
  end
end
