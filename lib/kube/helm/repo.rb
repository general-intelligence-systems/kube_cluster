# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"
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

test do
  # ── initialization ────────────────────────────────────────────────────

  it "initializes_with_name_and_url" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    repo.name.should == "bitnami"
  end

  it "raises_on_empty_name" do
    lambda {
      Kube::Helm::Repo.new("", url: "https://charts.example.com")
    }.should.raise ArgumentError
  end

  it "raises_on_nil_name" do
    lambda {
      Kube::Helm::Repo.new(nil, url: "https://charts.example.com")
    }.should.raise ArgumentError
  end

  # ── oci? delegation ──────────────────────────────────────────────────

  it "oci_returns_true_for_oci_url" do
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    repo.oci?.should.be.true
  end

  it "oci_returns_false_for_http_url" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    repo.oci?.should.be.false
  end

  # ── add / update / remove ────────────────────────────────────────────

  it "add_returns_self_for_oci" do
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    repo.add.should == repo
  end

  it "update_returns_self_for_oci" do
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    repo.update.should == repo
  end

  it "remove_returns_self_for_oci" do
    repo = Kube::Helm::Repo.new("ghcr", url: "oci://ghcr.io/my-org/charts")
    repo.remove.should == repo
  end

  it "add_runs_helm_repo_add" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; "" }
    begin
      result = repo.add
      result.should == repo
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end
  end

  it "update_runs_helm_repo_update" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; "" }
    begin
      repo.update
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "update"
  end

  it "remove_runs_helm_repo_remove" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    captured_cmd = nil
    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; "" }
    begin
      repo.remove
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "remove"
  end

  # ── fetch ────────────────────────────────────────────────────────────

  it "fetch_returns_chart_with_metadata" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    stub_chart_yaml = {
      "name" => "nginx",
      "version" => "18.1.0",
      "appVersion" => "1.25.0",
    }.to_yaml

    captured_cmds = []
    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd|
      captured_cmds << cmd
      cmd.include?("show") ? stub_chart_yaml : ""
    }
    begin
      chart = repo.fetch("nginx", version: "18.1.0")
      chart.name.should == "nginx"
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end
  end

  it "fetch_without_version" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")

    stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

    captured_cmds = []
    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd|
      captured_cmds << cmd
      cmd.include?("show") ? stub_chart_yaml : ""
    }
    begin
      chart = repo.fetch("nginx")
      chart.should.be.instance_of Kube::Helm::Chart
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end
  end

  it "fetch_propagates_cluster" do
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

    stub_chart_yaml = { "name" => "nginx", "version" => "18.1.0" }.to_yaml

    helm = cluster.connection.helm
    original = helm.method(:run)
    helm.define_singleton_method(:run) { |cmd|
      cmd.include?("show") ? stub_chart_yaml : ""
    }
    begin
      chart = repo.fetch("nginx", version: "18.1.0")
      chart.cluster.should == cluster
    ensure
      helm.define_singleton_method(:run, original)
    end
  end

  # ── cluster scoping ──────────────────────────────────────────────────

  it "initializes_without_cluster" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    repo.cluster.should.be.nil
  end

  it "initializes_with_cluster" do
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)
    repo.cluster.should == cluster
  end

  it "add_uses_cluster_helm_instance" do
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami", cluster: cluster)

    captured_cmd = nil
    helm = cluster.connection.helm
    original = helm.method(:run)
    helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; "" }
    begin
      repo.add
    ensure
      helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "add"
  end

  # ── to_s ──────────────────────────────────────────────────────────────

  it "to_s" do
    repo = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    repo.to_s.should == "bitnami (https://charts.bitnami.com/bitnami)"
  end
end
