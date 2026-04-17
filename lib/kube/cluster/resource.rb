# frozen_string_literal: true

require_relative "resource/dirty_tracking"
require_relative "resource/persistence"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      include DirtyTracking
      include Persistence

      attr_accessor :cluster

      def initialize(hash = {}, &block)
        @cluster = hash.delete(:cluster)
        super
        snapshot!
      end
    end
  end
end
