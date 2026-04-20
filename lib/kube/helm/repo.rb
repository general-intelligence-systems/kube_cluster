# frozen_string_literal: true

require_relative "endpoint"
require_relative "chart"

module Kube
  module Helm
    # Models a Helm chart repository (traditional or OCI).
    #
    # Wraps the lifecycle commands (`helm repo add`, `helm repo update`,
    # `helm repo remove`) and fetches charts for rendering.
    #
    # When a +cluster+ is provided, all Helm commands are scoped to that
    # cluster's kubeconfig.
    #
    #   repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #   chart = repo.fetch("nginx", version: "18.1.0")
    #   manifest = chart.apply_values({ "replicaCount" => 3 })
    #
    #   # One-liner
    #   manifest = Kube::Helm::Repo
    #     .new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #     .fetch("nginx", version: "18.1.0")
    #     .apply_values({ "replicaCount" => 3 })
    #
    class Repo
      attr_reader :name, :endpoint, :cluster

      # @param name [String] local alias for this repo (e.g. "bitnami")
      # @param url [String] repository URL (http(s) for traditional, oci:// for OCI)
      # @param cluster [Kube::Cluster::Instance, nil] optional cluster connection
      def initialize(name, url:, cluster: nil)
        unless name.is_a?(String) && !name.strip.empty?
          raise ArgumentError, "name must be a non-empty String"
        end

        @name     = name
        @endpoint = Endpoint.new(url)
        @cluster  = cluster
      end

      # Register this repo with the local Helm client.
      # No-op for OCI registries.
      #
      # @return [self]
      def add
        if endpoint.requires_add?
          repo_name = @name
          repo_url = endpoint.url
          cmd = helm.call { repo.add.(repo_name).(repo_url) }
          helm.run(cmd.to_s)
        end
        self
      end

      # Update the local chart index for this repo.
      # No-op for OCI registries.
      #
      # @return [self]
      def update
        if endpoint.requires_add?
          repo_name = @name
          cmd = helm.call { repo.update.(repo_name) }
          helm.run(cmd.to_s)
        end
        self
      end

      # Remove this repo from the local Helm client.
      # No-op for OCI registries.
      #
      # @return [self]
      def remove
        if endpoint.requires_add?
          repo_name = @name
          cmd = helm.call { repo.remove.(repo_name) }
          helm.run(cmd.to_s)
        end
        self
      end

      # Fetch a chart from this repo.
      #
      # Adds and updates the repo, retrieves the Chart.yaml metadata via
      # `helm show chart`, and returns a Chart object with the ref set
      # for subsequent helm commands.
      #
      # @param chart_name [String] the chart name (e.g. "nginx")
      # @param version [String, nil] chart version constraint (e.g. "18.1.0")
      # @return [Chart]
      def fetch(chart_name, version: nil)
        add
        update

        ref = endpoint.chart_ref(chart_name, repo_name: @name)

        cmd = helm.call { show.chart.(ref) }
        cmd = cmd.version(version) if version
        yaml_output = helm.run(cmd.to_s)

        data = YAML.safe_load(yaml_output, permitted_classes: [Symbol]) || {}
        Chart.new(data, ref: ref, cluster: @cluster)
      end

      # Is this an OCI-backed repo?
      def oci?
        endpoint.oci?
      end

      def to_s
        "#{@name} (#{endpoint.url})"
      end

      private

        def helm
          @cluster&.connection&.helm || Kube::Helm::Instance.new
        end
    end
  end
end
