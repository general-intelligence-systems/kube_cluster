# frozen_string_literal: true

require "kube/schema"
require_relative "../kube/errors"
require_relative "cluster/version"
require_relative "cluster/connection"
require_relative "cluster/instance"
require_relative "cluster/resource"
require_relative "cluster/custom_resource_definition"
require_relative "cluster/manifest"
require_relative "cluster/middleware"
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
          @schema   = schema_class.schema
          @defaults = schema_class.defaults

          def self.schema   = @schema   || superclass.schema
          def self.defaults = @defaults || superclass.defaults
        end
      end
    end
  end
end
