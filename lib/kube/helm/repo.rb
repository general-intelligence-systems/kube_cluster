# frozen_string_literal: true

require_relative "endpoint"
require_relative "chart"

module Kube
  module Helm
    # Models a Helm chart repository (traditional or OCI).
    #
    # Wraps the lifecycle commands (`helm repo add`, `helm repo update`,
    # `helm repo remove`) and produces Chart objects for rendering.
    #
    # When a +cluster+ is provided, all Helm commands are scoped to that
    # cluster's kubeconfig — mirroring how Kube::Cluster::Resource uses
    # +@cluster+ for kubectl commands.
    #
    #   # Without a cluster (uses system default / $KUBECONFIG)
    #   repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #
    #   # With a specific cluster connection
    #   cluster = Kube::Cluster.connect(kubeconfig: "/path/to/kubeconfig")
    #   repo = Kube::Helm::Repo.new("bitnami", url: "https://...", cluster: cluster)
    #
    #   # OCI registry (no add needed)
    #   repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    #
    class Repo
      attr_reader :name, :endpoint, :cluster

      # @param name [String] local alias for this repo (e.g. "bitnami")
      # @param url [String] repository URL (http(s) for traditional, oci:// for OCI)
      # @param cluster [Kube::Cluster::Instance, nil] optional cluster connection
      #   for kubeconfig scoping
      def initialize(name, url:, cluster: nil)
        unless name.is_a?(String) && !name.strip.empty?
          raise ArgumentError, "name must be a non-empty String"
        end

        @name     = name
        @endpoint = Endpoint.new(url)
        @cluster  = cluster
      end

      # Register this repo with the local Helm client.
      # Runs: helm repo add <name> <url>
      #
      # No-op for OCI registries (they don't require registration).
      #
      # @return [String, nil] command output, or nil for OCI
      def add
        if endpoint.requires_add?
          helm_run "repo add #{@name} #{endpoint.url}"
        end
      end

      # Update the local chart index for this repo.
      # Runs: helm repo update <name>
      #
      # No-op for OCI registries.
      #
      # @return [String, nil] command output, or nil for OCI
      def update
        if endpoint.requires_add?
          helm_run "repo update #{@name}"
        end
      end

      # Remove this repo from the local Helm client.
      # Runs: helm repo remove <name>
      #
      # No-op for OCI registries.
      #
      # @return [String, nil] command output, or nil for OCI
      def remove
        if endpoint.requires_add?
          helm_run "repo remove #{@name}"
        end
      end

      # Get a Chart reference from this repo.
      #
      # @param chart_name [String] the chart name (e.g. "nginx")
      # @param version [String, nil] chart version constraint (e.g. "18.1.0")
      # @return [Chart]
      def chart(chart_name, version: nil)
        Chart.new(
          endpoint.chart_ref(chart_name, repo_name: @name),
          version: version,
          cluster: @cluster
        )
      end

      # Is this an OCI-backed repo?
      def oci?
        endpoint.oci?
      end

      def to_s
        "#{@name} (#{endpoint.url})"
      end

      private

        # Run a helm command, scoped to the cluster's kubeconfig when present.
        # Falls back to the global Kube::Helm.run when no cluster is set.
        def helm_run(cmd)
          if @cluster
            @cluster.connection.helm.run(cmd)
          else
            Kube::Helm.run(cmd)
          end
        end
    end
  end
end
