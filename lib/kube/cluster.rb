# frozen_string_literal: true

require "kube/schema"
require_relative "../kube/errors"
require_relative "cluster/version"
require_relative "cluster/connection"
require_relative "cluster/instance"
require_relative "cluster/resource"
require_relative "cluster/middleware"
require_relative "cluster/manifest"
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

test do
  it "version" do
    Kube::Cluster::VERSION.should.not.be.nil
  end
end
