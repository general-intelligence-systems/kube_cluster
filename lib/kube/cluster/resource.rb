# frozen_string_literal: true

require_relative "resource/identity"
require_relative "resource/dirty_tracking"
require_relative "resource/persistence"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      include Identity
      include DirtyTracking
      include Persistence

      def initialize(hash = {}, &block)
        super
        snapshot!
      end
    end
  end
end
