# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

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

if __FILE__ == $0
  require "minitest/autorun"

  class RepoTest < Minitest::Test
    # ── initialization ────────────────────────────────────────────────────

    def test_initializes_with_name_and_url
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
      assert_equal "bitnami", repo.name
      assert_instance_of Kube::Helm::Endpoint, repo.endpoint
      assert_equal "https://charts.bitnami.com/bitnami", repo.endpoint.url
    end

    def test_raises_on_empty_name
      assert_raises(ArgumentError) do
        Kube::Helm::Repo.new("", url: "https://charts.example.com")
      end
    end

    def test_raises_on_nil_name
      assert_raises(ArgumentError) do
        Kube::Helm::Repo.new(nil, url: "https://charts.example.com")
      end
    end

    # ── oci? delegation ──────────────────────────────────────────────────

    def test_oci_returns_true_for_oci_url
      repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
      assert repo.oci?
    end

    def test_oci_returns_false_for_http_url
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
      refute repo.oci?
    end

    # ── add / update / remove ────────────────────────────────────────────

    def test_add_returns_self_for_oci
      repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
      assert_equal repo, repo.add
    end

    def test_update_returns_self_for_oci
      repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
      assert_equal repo, repo.update
    end

    def test_remove_returns_self_for_oci
      repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
      assert_equal repo, repo.remove
    end

    def test_add_runs_helm_repo_add
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

      captured_cmd = nil
      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
        result = repo.add
        assert_equal repo, result
      end

      assert_includes captured_cmd, "repo"
      assert_includes captured_cmd, "add"
      assert_includes captured_cmd, "bitnami"
      assert_includes captured_cmd, "https://charts.bitnami.com/bitnami"
    end

    def test_update_runs_helm_repo_update
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

      captured_cmd = nil
      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
        repo.update
      end

      assert_includes captured_cmd, "repo"
      assert_includes captured_cmd, "update"
      assert_includes captured_cmd, "bitnami"
    end

    def test_remove_runs_helm_repo_remove
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

      captured_cmd = nil
      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
        repo.remove
      end

      assert_includes captured_cmd, "repo"
      assert_includes captured_cmd, "remove"
      assert_includes captured_cmd, "bitnami"
    end

    # ── fetch ────────────────────────────────────────────────────────────

    def test_fetch_returns_chart_with_metadata
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

      stub_chart_yaml = {
        "name" => "nginx",
        "version" => "18.1.0",
        "appVersion" => "1.25.0",
      }.to_yaml

      captured_cmds = []
      Kube::Helm.stub(:run, ->(cmd) {
        captured_cmds << cmd
        cmd.include?("show") ? stub_chart_yaml : ""
      }) do
        chart = repo.fetch("nginx", version: "18.1.0")

        assert_instance_of Kube::Helm::Chart, chart
        assert_equal "nginx", chart.name
        assert_equal "18.1.0", chart.version
        assert_equal "1.25.0", chart.app_version
        assert_equal "bitnami/nginx", chart.ref
        assert_nil chart.path
      end

      # Should have run: repo add, repo update, show chart
      show_cmd = captured_cmds.find { |c| c.include?("show") && c.include?("chart") }
      assert show_cmd, "Expected a show chart command"
      assert_includes show_cmd, "bitnami/nginx"
      assert_includes show_cmd, "--version=18.1.0"
    end

    def test_fetch_without_version
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

      stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

      captured_cmds = []
      Kube::Helm.stub(:run, ->(cmd) {
        captured_cmds << cmd
        cmd.include?("show") ? stub_chart_yaml : ""
      }) do
        chart = repo.fetch("nginx")
        assert_instance_of Kube::Helm::Chart, chart
        assert_nil chart.path
      end

      show_cmd = captured_cmds.find { |c| c.include?("show") && c.include?("chart") }
      refute_includes show_cmd, "--version"
    end

    def test_fetch_propagates_cluster
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

      stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

      cluster.connection.helm.stub(:run, ->(cmd) {
        cmd.include?("show") ? stub_chart_yaml : ""
      }) do
        chart = repo.fetch("nginx", version: "18.1.0")
        assert_equal cluster, chart.cluster
        assert_equal "bitnami/nginx", chart.ref
      end
    end

    # ── cluster scoping ──────────────────────────────────────────────────

    def test_initializes_without_cluster
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
      assert_nil repo.cluster
    end

    def test_initializes_with_cluster
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)
      assert_equal cluster, repo.cluster
    end

    def test_add_uses_cluster_helm_instance
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

      captured_cmd = nil
      cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
        repo.add
      end

      assert_includes captured_cmd, "repo"
      assert_includes captured_cmd, "add"
      assert_includes captured_cmd, "bitnami"
    end

    # ── to_s ──────────────────────────────────────────────────────────────

    def test_to_s
      repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
      assert_equal "bitnami (https://charts.bitnami.com/bitnami)", repo.to_s
    end
  end
end
