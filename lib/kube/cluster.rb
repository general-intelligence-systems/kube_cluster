# frozen_string_literal: true

require "bundler/setup"
require "kube/schema"
require "active_support/core_ext/string/inflections"

require_relative "../kube/errors"
require_relative "cluster/version"
require_relative "cluster/script_command"
require 'kube/ctl'
require_relative 'helm/repo'

module Kube
  def self.cluster
    Cluster
  end

  module Cluster
    def self.connect(kubeconfig:)
      Instance.new(kubeconfig: kubeconfig)
    end

    # Returns an anonymous subclass of Kube::Cluster::Resource for the
    # given Kubernetes kind, mirroring Kube::Schema[kind] but with
    # dirty tracking, persistence, and resource helper methods.
    #
    #   Kube::Cluster["Deployment"].new { metadata.name = "web" }
    #
    def self.[](kind)
      @resource_classes ||= {}
      @resource_classes[kind] ||= begin
        schema_class = Kube::Schema[kind]
        Class.new(Resource) do
          @schema            = schema_class.schema
          @defaults          = schema_class.defaults
          @schema_properties = schema_class.schema_properties

          def self.schema            = @schema            || superclass.schema
          def self.defaults          = @defaults          || superclass.defaults
          def self.schema_properties = @schema_properties || superclass.schema_properties
        end
      end
    end
  end
end

require "kube/cluster/middleware"
require "kube/cluster/resource/dirty_tracking"
require "kube/cluster/resource/persistence"

Dir.glob("#{__dir__}/cluster/**/*.rb").sort.each do |path|
  require path
end

