# frozen_string_literal: true

require "test_helper"

class ChartTest < Minitest::Test
  # ── initialization ────────────────────────────────────────────────────

  def test_initializes_with_ref_and_version
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0")
    assert_equal "bitnami/nginx", chart.ref
    assert_equal "18.1.0", chart.version
  end

  def test_initializes_without_version
    chart = Kube::Helm::Chart.new("bitnami/nginx")
    assert_equal "bitnami/nginx", chart.ref
    assert_nil chart.version
  end

  # ── to_s ──────────────────────────────────────────────────────────────

  def test_to_s_with_version
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0")
    assert_equal "bitnami/nginx:18.1.0", chart.to_s
  end

  def test_to_s_without_version
    chart = Kube::Helm::Chart.new("bitnami/nginx")
    assert_equal "bitnami/nginx", chart.to_s
  end

  # ── build_template_command (via template) ──────────────────────────────
  # We test command construction by stubbing Kube::Helm.run to capture
  # the command string, and returning valid YAML so Manifest.parse works.

  def test_template_builds_correct_command
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0")

    captured_cmd = nil
    stub_yaml = { "kind" => "Deployment", "apiVersion" => "apps/v1" }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "my-release", namespace: "production")
    end

    assert_includes captured_cmd, "template my-release bitnami/nginx"
    assert_includes captured_cmd, "--version 18.1.0"
    assert_includes captured_cmd, "--namespace production"
  end

  def test_template_without_version_or_namespace
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "test")
    end

    assert_equal "template test bitnami/nginx", captured_cmd
  end

  def test_template_with_values_hash
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "test", values: { "replicaCount" => 3 })
    end

    assert_match(/--values .*helm-values.*\.yaml/, captured_cmd)
  end

  def test_template_with_values_file
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "test", values_file: "/path/to/values.yaml")
    end

    assert_includes captured_cmd, "--values /path/to/values.yaml"
  end

  def test_template_returns_manifest
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    stub_yaml = [
      { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } },
      { "kind" => "Service", "apiVersion" => "v1", "metadata" => { "name" => "web" } }
    ].map(&:to_yaml).join("")

    result = nil
    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      result = chart.template(release: "test")
    end

    assert_instance_of Kube::Schema::Manifest, result
    assert_equal 2, result.count

    kinds = result.map(&:kind)
    assert_includes kinds, "Deployment"
    assert_includes kinds, "Service"
  end

  # ── pull command ──────────────────────────────────────────────────────

  def test_pull_builds_correct_command
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0")

    captured_cmd = nil

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      chart.pull(destination: "/tmp/charts")
    end

    assert_includes captured_cmd, "pull bitnami/nginx"
    assert_includes captured_cmd, "--version 18.1.0"
    assert_includes captured_cmd, "--destination /tmp/charts"
    assert_includes captured_cmd, "--untar"
  end

  def test_pull_without_untar
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    captured_cmd = nil

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      chart.pull(destination: "/tmp/charts", untar: false)
    end

    refute_includes captured_cmd, "--untar"
  end

  # ── show_values command ───────────────────────────────────────────────

  def test_show_values_builds_correct_command
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0")

    captured_cmd = nil
    stub_yaml = { "replicaCount" => 1, "service" => { "type" => "ClusterIP" } }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      result = chart.show_values
      assert_equal 1, result["replicaCount"]
      assert_equal "ClusterIP", result.dig("service", "type")
    end

    assert_includes captured_cmd, "show values bitnami/nginx"
    assert_includes captured_cmd, "--version 18.1.0"
  end

  # ── cluster: kubeconfig scoping ────────────────────────────────────

  def test_initializes_without_cluster
    chart = Kube::Helm::Chart.new("bitnami/nginx")
    assert_nil chart.cluster
  end

  def test_initializes_with_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.new("bitnami/nginx", cluster: cluster)
    assert_equal cluster, chart.cluster
  end

  def test_template_uses_cluster_helm_instance
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.new("bitnami/nginx", cluster: cluster)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    # Stub the cluster's helm instance run method
    cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "test")
    end

    assert_equal "template test bitnami/nginx", captured_cmd
  end

  def test_template_without_cluster_uses_global_helm_run
    chart = Kube::Helm::Chart.new("bitnami/nginx")

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.template(release: "test")
    end

    assert_equal "template test bitnami/nginx", captured_cmd
  end

  def test_pull_uses_cluster_helm_instance
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0", cluster: cluster)

    captured_cmd = nil

    cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; "" }) do
      chart.pull(destination: "/tmp/charts")
    end

    assert_includes captured_cmd, "pull bitnami/nginx"
    assert_includes captured_cmd, "--version 18.1.0"
  end

  def test_show_values_uses_cluster_helm_instance
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.new("bitnami/nginx", version: "18.1.0", cluster: cluster)

    captured_cmd = nil
    stub_yaml = { "replicaCount" => 1 }.to_yaml

    cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.show_values
    end

    assert_includes captured_cmd, "show values bitnami/nginx"
  end

  # ── crds ────────────────────────────────────────────────────────────

  def test_crds_returns_custom_resource_definition_objects
    chart = Kube::Helm::Chart.new("jetstack/cert-manager")

    stub_yaml = [
      { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "cert-manager" } },
      {
        "kind" => "CustomResourceDefinition",
        "apiVersion" => "apiextensions.k8s.io/v1",
        "metadata" => { "name" => "clusterissuers.cert-manager.io" },
        "spec" => {
          "group" => "cert-manager.io",
          "names" => { "kind" => "ClusterIssuer" },
          "versions" => [
            {
              "name" => "v1",
              "schema" => {
                "openAPIV3Schema" => {
                  "type" => "object",
                  "properties" => {
                    "spec" => {
                      "type" => "object",
                      "properties" => {
                        "acme" => { "type" => "object" },
                      },
                    },
                  },
                },
              },
            },
          ],
        },
      },
    ].map(&:to_yaml).join("")

    result = nil
    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      result = chart.crds
    end

    assert_equal 1, result.length
    assert_equal "CustomResourceDefinition", result.first.kind
    assert result.first.respond_to?(:to_json_schema)
  end

  def test_crds_to_json_schema
    chart = Kube::Helm::Chart.new("jetstack/cert-manager")

    stub_yaml = [
      {
        "kind" => "CustomResourceDefinition",
        "apiVersion" => "apiextensions.k8s.io/v1",
        "metadata" => { "name" => "clusterissuers.cert-manager.io" },
        "spec" => {
          "group" => "cert-manager.io",
          "names" => { "kind" => "ClusterIssuer" },
          "versions" => [
            {
              "name" => "v1",
              "schema" => {
                "openAPIV3Schema" => {
                  "type" => "object",
                  "properties" => {
                    "spec" => { "type" => "object" },
                  },
                },
              },
            },
          ],
        },
      },
    ].map(&:to_yaml).join("")

    crd = nil
    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      crd = chart.crds.first
    end

    s = crd.to_json_schema
    assert_equal "ClusterIssuer", s[:kind]
    assert_equal "cert-manager.io/v1", s[:api_version]
    assert_equal "object", s[:schema]["type"]
  end

  def test_crds_register_flow
    chart = Kube::Helm::Chart.new("jetstack/cert-manager")

    stub_yaml = [
      {
        "kind" => "CustomResourceDefinition",
        "apiVersion" => "apiextensions.k8s.io/v1",
        "metadata" => { "name" => "clusterissuers.cert-manager.io" },
        "spec" => {
          "group" => "cert-manager.io",
          "names" => { "kind" => "ClusterIssuer" },
          "versions" => [
            {
              "name" => "v1",
              "schema" => {
                "openAPIV3Schema" => {
                  "type" => "object",
                  "properties" => {
                    "spec" => { "type" => "object" },
                  },
                },
              },
            },
          ],
        },
      },
    ].map(&:to_yaml).join("")

    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      chart.crds.each do |crd|
        s = crd.to_json_schema
        Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
      end
    end

    klass = Kube::Schema["ClusterIssuer"]
    assert klass < Kube::Schema::Resource

    resource = klass.new {
      metadata.name = "test-issuer"
    }
    assert_equal "ClusterIssuer", resource.kind
    assert_equal "cert-manager.io/v1", resource.apiVersion
    assert_equal "test-issuer", resource.metadata.name
  ensure
    Kube::Schema.reset_custom_schemas!
  end

  def test_crds_skips_non_crd_resources
    chart = Kube::Helm::Chart.new("jetstack/cert-manager")

    stub_yaml = [
      { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "cm" } },
      { "kind" => "Service", "apiVersion" => "v1", "metadata" => { "name" => "cm" } },
    ].map(&:to_yaml).join("")

    result = nil
    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      result = chart.crds
    end

    assert_equal [], result
  end

  def test_crds_handles_multiple_crds
    chart = Kube::Helm::Chart.new("jetstack/cert-manager")

    stub_yaml = [
      {
        "kind" => "CustomResourceDefinition",
        "apiVersion" => "apiextensions.k8s.io/v1",
        "metadata" => { "name" => "certificates.cert-manager.io" },
        "spec" => {
          "group" => "cert-manager.io",
          "names" => { "kind" => "Certificate" },
          "versions" => [
            { "name" => "v1", "schema" => { "openAPIV3Schema" => { "type" => "object" } } },
          ],
        },
      },
      {
        "kind" => "CustomResourceDefinition",
        "apiVersion" => "apiextensions.k8s.io/v1",
        "metadata" => { "name" => "issuers.cert-manager.io" },
        "spec" => {
          "group" => "cert-manager.io",
          "names" => { "kind" => "Issuer" },
          "versions" => [
            { "name" => "v1", "schema" => { "openAPIV3Schema" => { "type" => "object" } } },
          ],
        },
      },
    ].map(&:to_yaml).join("")

    result = nil
    Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
      result = chart.crds
    end

    assert_equal 2, result.length
    assert result.all? { |crd| crd.respond_to?(:to_json_schema) }
  end
end
