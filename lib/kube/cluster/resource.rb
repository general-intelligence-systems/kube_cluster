# frozen_string_literal: true

require_relative "resource/dirty_tracking"
require_relative "resource/persistence"

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
      end

      # Build a new resource of the same schema subclass from a hash.
      def rebuild(hash)
        self.class.new(hash)
      end

      # Read a label value from the resource.
      def label(key)
        labels = to_h.dig(:metadata, :labels) || {}
        labels[key.to_sym] || labels[key.to_s]
      end

      # Read an annotation value from the resource.
      def annotation(key)
        annotations = to_h.dig(:metadata, :annotations) || {}
        annotations[key.to_sym] || annotations[key.to_s]
      end

      # The resource kind as a String (e.g. "Deployment").
      def kind
        h = to_h
        (h[:kind] || h["kind"]).to_s
      end

      # Is this a resource that contains a pod template?
      def pod_bearing?
        POD_BEARING_KINDS.include?(kind)
      end

      # Is this a cluster-scoped resource (no namespace)?
      def cluster_scoped?
        CLUSTER_SCOPED_KINDS.include?(kind)
      end

      # Returns the pod template spec path from a resource hash,
      # accounting for CronJob's extra nesting.
      def pod_template(hash)
        if (hash[:kind] || hash["kind"]).to_s == "CronJob"
          hash.dig(:spec, :jobTemplate, :spec, :template, :spec)
        else
          hash.dig(:spec, :template, :spec)
        end
      end

      # Walk every container list in a pod spec (containers,
      # initContainers) and yield each container hash.
      def each_container(pod_spec, &block)
        return unless pod_spec

        [:containers, :initContainers].each do |key|
          Array(pod_spec[key]).each(&block)
        end
      end

    end
  end
end
