# frozen_string_literal: true

require_relative "cluster/version"
require_relative "cluster/tree_node"
require_relative "cluster/resource_selector"
require_relative "cluster/query_builder"
require_relative "cluster/command_node"
require_relative "cluster/ctl"

module Kube
  module Cluster
    def self.ctl
      Ctl.new
    end
  end
end
