# frozen_string_literal: true

require "kube/schema"
require_relative "../kube/errors"
require_relative "cluster/version"
require_relative "cluster/connection"
require_relative "cluster/instance"
require_relative "cluster/resource"
require_relative "cluster/manifest"
require 'kube/ctl'

module Kube
  def self.cluster
    Cluster
  end

  module Cluster
    def self.connect(kubeconfig:)
      Instance.new(kubeconfig: kubeconfig)
    end
  end
end
