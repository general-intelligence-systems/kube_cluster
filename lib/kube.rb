# frozen_string_literal: true

require_relative "kube/cluster"

module Kube
  def self.cluster
    Cluster
  end
end
