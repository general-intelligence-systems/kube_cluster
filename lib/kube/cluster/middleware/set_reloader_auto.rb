# frozen_string_literal: true

require "bundler/setup"
require 'kube/cluster'

module Kube
  module Cluster
    class Middleware
      # Marks Deployments/StatefulSets/DaemonSets for Stakater Reloader.
      # @example
      #   use SetReloaderAuto
      class SetReloaderAuto < Middleware
        KINDS = %w[Deployment StatefulSet DaemonSet].freeze

        def initialize
          super(filter: ->(r) { KINDS.include?(r.kind) })
        end

        def call(manifest)
          manifest.resources.map! { |resource|
            filter(resource) {
              h = resource.to_h
              h[:metadata] ||= {}
              h[:metadata][:annotations] ||= {}
              h[:metadata][:annotations][:'reloader.stakater.com/auto'] = 'true'
              resource.rebuild(h)
            }
          }
        end
      end
    end
  end
end
