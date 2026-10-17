# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    class Resource < Kube::Schema::Resource
      include DirtyTracking
      include Persistence

      attr_accessor :cluster

      POD_BEARING_KINDS = %w[
        Deployment
        StatefulSet
        DaemonSet
        Job
        CronJob
        ReplicaSet
      ].freeze

      CLUSTER_SCOPED_KINDS = %w[
        Namespace
        ClusterRole
        ClusterRoleBinding
        PersistentVolume
        StorageClass
        IngressClass
        CustomResourceDefinition
        PriorityClass
        RuntimeClass
        VolumeAttachment
        CSIDriver
        CSINode
      ].freeze

      def initialize(hash = {}, &block)
        @cluster = hash.delete(:cluster)
        super
        snapshot!

        begin
          extend Object.const_get(
            "Kube::Cluster::Resource::Extensions::#{kind}",
          )
        rescue
          nil
        end
      end

      # Build a new resource of the same subclass.
      # @parameter hash [Hash] the resource data, with :kind and :apiVersion.
      # @returns [Resource] a new instance looked up via Kube::Cluster[].
      #
      # @example self.class.new(**hash) would raise for a subclass like this
      #   class ExampleServiceSubclass < Kube::Cluster["Service"]
      #     def initialize(name:, port:, **options, &block)
      #       super() { metadata.name = name }
      #     end
      #   end
      def rebuild(hash = {})
        kind = hash.delete(:kind).to_s
        api_version = hash.delete(:apiVersion)&.to_s
        if api_version
          lookup = "#{api_version}/#{kind}"
        else
          lookup = kind
        end
        Kube::Cluster[lookup].new(**hash)
      end

      # Read a label value from the resource.
      # @parameter key [String, Symbol] the label key.
      # @returns [String, nil] the label value, if set.
      def label(key)
        labels = to_h.dig(:metadata, :labels) || {}
        labels[key.to_sym] || labels[key.to_s]
      end

      # Read an annotation value from the resource.
      # @parameter key [String, Symbol] the annotation key.
      # @returns [String, nil] the annotation value, if set.
      def annotation(key)
        annotations = to_h.dig(:metadata, :annotations) || {}
        annotations[key.to_sym] || annotations[key.to_s]
      end

      # The resource kind as a String (e.g. "Deployment").
      # @returns [String] the resource kind.
      def kind
        h = to_h
        (h[:kind] || h["kind"]).to_s
      end

      # Is this a resource that contains a pod template?
      # @returns [Boolean] true for Deployment, Job, CronJob, etc.
      def pod_bearing?
        POD_BEARING_KINDS.include?(kind)
      end

      # Is this a cluster-scoped resource (no namespace)?
      # @returns [Boolean] true for Namespace, ClusterRole, etc.
      def cluster_scoped?
        CLUSTER_SCOPED_KINDS.include?(kind)
      end

      # The pod template spec path, accounting for CronJob's nesting.
      # @parameter hash [Hash] a resource hash.
      # @returns [Hash, nil] the pod spec at that path.
      def pod_template(hash)
        if (hash[:kind] || hash["kind"]).to_s == "CronJob"
          hash.dig(
            :spec,
            :jobTemplate,
            :spec,
            :template,
            :spec,
          )
        else
          hash.dig(:spec, :template, :spec)
        end
      end

      # Walk containers and initContainers, yielding each container.
      # @parameter pod_spec [Hash, nil] a pod spec.
      # @yields {|container| ...} each container hash.
      def each_container(pod_spec, &block)
        if pod_spec
          [:containers, :initContainers].each do |key|
            Array(pod_spec[key]).each(&block)
          end
        else
          nil
        end
      end

    end
  end
end

__END__

class ExampleServiceSubclass < Kube::Cluster["Service"]
  def initialize(name:, port:, **options, &block)
    super() {
      metadata.name = name
      metadata.labels = { "app" => name }
      spec.selector = { "app" => name }
      spec.ports = [{ port: port, targetPort: port, protocol: "TCP" }]

      instance_exec(&block) if block_given?
    }

  end
end

it "rebuilds properly" do
  ExampleServiceSubclass.new(name: "example-service", port: 3000).tap do |service|
    lambda{ service.rebuild(**service.to_h) }.should.not.raise
  end
end
