# frozen_string_literal: true

require "test_helper"

class ChartTest < Minitest::Test
  # ── initialization ────────────────────────────────────────────────────

  def test_initializes_with_data_hash
    chart = Kube::Helm::Chart.new({ "name" => "my-app", "version" => "1.0.0", "appVersion" => "2.5.0" })
    assert_equal "my-app", chart.name
    assert_equal "1.0.0", chart.version
    assert_equal "2.5.0", chart.app_version
  end

  def test_initializes_with_block
    chart = Kube::Helm::Chart.new {
      self.name = "my-app"
      self.version = "1.0.0"
      self.appVersion = "2.5.0"
      self.description = "A test chart"
    }

    assert_equal "my-app", chart.name
    assert_equal "1.0.0", chart.version
    assert_equal "2.5.0", chart.app_version
    assert_equal "A test chart", chart.description
  end

  def test_initializes_empty
    chart = Kube::Helm::Chart.new
    assert_nil chart.name
    assert_nil chart.version
    assert_nil chart.app_version
    assert_nil chart.description
    assert_nil chart.type
    assert_equal [], chart.dependencies
  end

  def test_initializes_with_path
    chart = Kube::Helm::Chart.new({ "name" => "x" }, path: "/tmp/charts/x")
    assert_equal "/tmp/charts/x", chart.path
  end

  def test_initializes_with_cluster
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.new({ "name" => "x" }, cluster: cluster)
    assert_equal cluster, chart.cluster
  end

  # ── Chart.open ───────────────────────────────────────────────────────

  def test_open_reads_chart_yaml
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), {
        "name" => "test-chart",
        "version" => "0.1.0",
        "appVersion" => "1.0.0",
        "description" => "A test chart",
        "type" => "application",
      }.to_yaml)

      chart = Kube::Helm::Chart.open(dir)
      assert_equal "test-chart", chart.name
      assert_equal "0.1.0", chart.version
      assert_equal "1.0.0", chart.app_version
      assert_equal "A test chart", chart.description
      assert_equal "application", chart.type
      assert_equal dir, chart.path
    end
  end

  def test_open_raises_without_chart_yaml
    Dir.mktmpdir do |dir|
      assert_raises(Kube::Error) { Kube::Helm::Chart.open(dir) }
    end
  end

  def test_open_with_cluster
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "x", "version" => "1.0.0" }.to_yaml)
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")

      chart = Kube::Helm::Chart.open(dir, cluster: cluster)
      assert_equal cluster, chart.cluster
    end
  end

  # ── to_s ──────────────────────────────────────────────────────────────

  def test_to_s_with_version
    chart = Kube::Helm::Chart.new({ "name" => "nginx", "version" => "18.1.0" })
    assert_equal "nginx:18.1.0", chart.to_s
  end

  def test_to_s_without_version
    chart = Kube::Helm::Chart.new({ "name" => "nginx" })
    assert_equal "nginx", chart.to_s
  end

  # ── apply_values ─────────────────────────────────────────────────────

  def test_apply_values_raises_without_source
    chart = Kube::Helm::Chart.new({ "name" => "my-app" })
    assert_raises(Kube::Error) { chart.apply_values({ "replicaCount" => 3 }) }
  end

  def test_apply_values_builds_correct_command
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({ "replicaCount" => 3 })
      end

      assert_includes captured_cmd, "template"
      assert_includes captured_cmd, "my-app"
      assert_includes captured_cmd, dir
      assert_match(/-f .*helm-values.*\.yaml/, captured_cmd)
    end
  end

  def test_apply_values_with_custom_release
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({}, release: "custom-release")
      end

      assert_includes captured_cmd, "custom-release"
    end
  end

  def test_apply_values_with_namespace
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({}, namespace: "production")
      end

      assert_includes captured_cmd, "--namespace=production"
    end
  end

  def test_apply_values_returns_manifest
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      stub_yaml = [
        { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } },
        { "kind" => "Service", "apiVersion" => "v1", "metadata" => { "name" => "web" } },
      ].map(&:to_yaml).join("")

      result = nil
      Kube::Helm.stub(:run, ->(_cmd) { stub_yaml }) do
        result = chart.apply_values({ "replicaCount" => 3 })
      end

      assert_instance_of Kube::Schema::Manifest, result
      assert_equal 2, result.count

      kinds = result.map(&:kind)
      assert_includes kinds, "Deployment"
      assert_includes kinds, "Service"
    end
  end

  def test_apply_values_defaults_release_to_chart_name
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "nginx", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({})
      end

      assert_includes captured_cmd, "nginx"
    end
  end

  # ── show_values ──────────────────────────────────────────────────────

  def test_show_values
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "replicaCount" => 1, "service" => { "type" => "ClusterIP" } }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        result = chart.show_values
        assert_equal 1, result["replicaCount"]
        assert_equal "ClusterIP", result.dig("service", "type")
      end

      assert_includes captured_cmd, "show"
      assert_includes captured_cmd, "values"
      assert_includes captured_cmd, dir
    end
  end

  def test_show_values_raises_without_source
    chart = Kube::Helm::Chart.new({ "name" => "my-app" })
    assert_raises(Kube::Error) { chart.show_values }
  end

  # ── crds ─────────────────────────────────────────────────────────────

  def test_crds_returns_custom_resource_definition_objects
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "cert-manager", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      stub_yaml = [
        { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "cm" } },
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
                    "properties" => { "spec" => { "type" => "object" } },
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
  end

  def test_crds_raises_without_source
    chart = Kube::Helm::Chart.new({ "name" => "my-app" })
    assert_raises(Kube::Error) { chart.crds }
  end

  # ── cluster scoping ──────────────────────────────────────────────────

  def test_apply_values_uses_cluster_helm_instance
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
      chart = Kube::Helm::Chart.open(dir, cluster: cluster)

      captured_cmd = nil
      stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

      cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({ "foo" => "bar" })
      end

      assert_includes captured_cmd, "template"
      assert_includes captured_cmd, "my-app"
    end
  end

  def test_show_values_uses_cluster_helm_instance
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
      chart = Kube::Helm::Chart.open(dir, cluster: cluster)

      captured_cmd = nil
      stub_yaml = { "replicaCount" => 1 }.to_yaml

      cluster.connection.helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.show_values
      end

      assert_includes captured_cmd, "show"
      assert_includes captured_cmd, "values"
    end
  end

  # ── remote chart (ref-based) ─────────────────────────────────────────

  def test_initializes_with_ref
    chart = Kube::Helm::Chart.new({ "name" => "nginx", "version" => "18.1.0" }, ref: "bitnami/nginx")
    assert_equal "bitnami/nginx", chart.ref
    assert_nil chart.path
  end

  def test_apply_values_with_ref_uses_ref_and_version
    chart = Kube::Helm::Chart.new(
      { "name" => "nginx", "version" => "18.1.0" },
      ref: "bitnami/nginx"
    )

    captured_cmd = nil
    stub_yaml = { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.apply_values({ "replicaCount" => 3 })
    end

    assert_includes captured_cmd, "template"
    assert_includes captured_cmd, "nginx"
    assert_includes captured_cmd, "bitnami/nginx"
    assert_includes captured_cmd, "--version=18.1.0"
  end

  def test_apply_values_with_path_does_not_add_version_flag
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
      chart = Kube::Helm::Chart.open(dir)

      captured_cmd = nil
      stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

      Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
        chart.apply_values({})
      end

      refute_includes captured_cmd, "--version"
    end
  end

  def test_show_values_with_ref
    chart = Kube::Helm::Chart.new(
      { "name" => "nginx", "version" => "18.1.0" },
      ref: "bitnami/nginx"
    )

    captured_cmd = nil
    stub_yaml = { "replicaCount" => 1 }.to_yaml

    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      chart.show_values
    end

    assert_includes captured_cmd, "show"
    assert_includes captured_cmd, "values"
    assert_includes captured_cmd, "bitnami/nginx"
    assert_includes captured_cmd, "--version=18.1.0"
  end

  def test_crds_with_ref
    chart = Kube::Helm::Chart.new(
      { "name" => "cert-manager", "version" => "1.17.2" },
      ref: "jetstack/cert-manager"
    )

    stub_yaml = [
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

    captured_cmd = nil
    Kube::Helm.stub(:run, ->(cmd) { captured_cmd = cmd; stub_yaml }) do
      result = chart.crds
      assert_equal 1, result.length
    end

    assert_includes captured_cmd, "show"
    assert_includes captured_cmd, "crds"
    assert_includes captured_cmd, "jetstack/cert-manager"
    assert_includes captured_cmd, "--version=1.17.2"
  end
end
