# frozen_string_literal: true

if __FILE__ == $0
  require "bundler/setup"
  require "kube/cluster"
end

require "tempfile"
require "yaml"

module Kube
  module Helm
    # Represents a Helm Chart.yaml as a Ruby object.
    #
    # The Chart holds metadata from Chart.yaml and can render resources
    # via #apply_values. It can be backed by either a local directory
    # (with templates on disk) or a remote chart reference.
    #
    #   # Virtual chart (just metadata, no templates)
    #   chart = Kube::Helm::Chart.new {
    #     name = "my-app"
    #     version = "1.0.0"
    #     appVersion = "3.4.5"
    #   }
    #
    #   # Load from a local chart directory
    #   chart = Kube::Helm::Chart.open("./charts/my-app")
    #   manifest = chart.apply_values({ "replicaCount" => 3 })
    #
    #   # From a remote repo
    #   manifest = Kube::Helm::Repo
    #     .new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #     .fetch("nginx", version: "18.1.0")
    #     .apply_values({ "replicaCount" => 3 })
    #
    class Chart
      attr_reader :path, :ref, :cluster

      # Open a chart from a local directory. Reads Chart.yaml and stores
      # the path so that helm commands run against the local chart.
      #
      # @param path [String] path to the chart directory
      # @param cluster [Kube::Cluster::Instance, nil] optional cluster connection
      # @return [Chart]
      def self.open(path, cluster: nil)
        chart_file = File.join(path, "Chart.yaml")
        raise Kube::Error, "No Chart.yaml found at #{path}" unless File.exist?(chart_file)

        yaml = YAML.safe_load_file(chart_file)
        new(yaml, path: path, cluster: cluster)
      end

      # @param data [Hash] Chart.yaml content (string or symbol keys)
      # @param path [String, nil] filesystem path to chart directory (local charts)
      # @param ref [String, nil] chart reference for helm commands (remote charts)
      # @param cluster [Kube::Cluster::Instance, nil] optional cluster connection
      def initialize(data = {}, path: nil, ref: nil, cluster: nil, &block)
        @data    = deep_symbolize_keys(data)
        @path    = path
        @ref     = ref
        @cluster = cluster
        @data.instance_exec(&block) if block_given?
      end

      def name         = @data[:name]
      def version      = @data[:version]
      def app_version  = @data[:appVersion]
      def description  = @data[:description]
      def type         = @data[:type]
      def dependencies = @data[:dependencies] || []

      # Render the chart templates with values applied.
      #
      # Shells out to `helm template` and returns a Manifest of typed
      # Resource objects.
      #
      # @param values [Hash] values to apply to the chart templates
      # @param release [String, nil] release name (defaults to chart name)
      # @param namespace [String, nil] namespace for rendered resources
      # @return [Kube::Schema::Manifest]
      def apply_values(values, release: nil, namespace: nil)
        raise Kube::Error, "No chart source" unless source

        release_name = release || name
        source_ref = source
        ver = version_flag

        cmd = helm.call { template.(release_name).(source_ref).include_crds(true) }
        cmd = cmd.version(ver) if ver
        cmd = cmd.namespace(namespace) if namespace

        if values.is_a?(Hash) && values.any?
          tmpfile = write_values_tempfile(values)
          cmd = cmd.f(tmpfile.path)
        end

        Kube::Schema::Manifest.parse(helm.run(cmd.to_s))
      end

      # Show the chart's default values.
      #
      # @return [Hash] the default values as a Ruby hash
      def show_values
        raise Kube::Error, "No chart source" unless source

        source_ref = source
        ver = version_flag
        cmd = helm.call { show.values.(source_ref) }
        cmd = cmd.version(ver) if ver

        YAML.safe_load(helm.run(cmd.to_s), permitted_classes: [Symbol]) || {}
      end

      # Return the chart's CRDs as Kube::Cluster::CustomResourceDefinition objects.
      #
      # First tries `helm show crds`. If that returns nothing (some charts
      # ship CRDs in templates rather than the crds/ directory), falls back
      # to rendering via `helm template --set installCRDs=true` and filtering
      # for CustomResourceDefinition resources.
      #
      #   chart.crds.each do |crd|
      #     s = crd.to_json_schema
      #     Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
      #   end
      #
      # @return [Array<Kube::Cluster::CustomResourceDefinition>]
      def crds
        raise Kube::Error, "No chart source" unless source

        results = crds_from_show
        results = crds_from_template if results.empty?
        results
      end

      def to_s
        version ? "#{name}:#{version}" : name.to_s
      end

      private

        def crds_from_show
          source_ref = source
          ver = version_flag
          cmd = helm.call { show.crds.(source_ref) }
          cmd = cmd.version(ver) if ver

          yaml_output = helm.run(cmd.to_s)
          parse_crds(yaml_output)
        end

        def crds_from_template
          source_ref = source
          ver = version_flag
          release_name = name || "crds"

        cmd = helm.call { template.(release_name).(source_ref).include_crds(true) }
          cmd = cmd.version(ver) if ver
          cmd = cmd.set("installCRDs=true")

          yaml_output = helm.run(cmd.to_s)
          parse_crds(yaml_output)
        end

        def parse_crds(yaml_output)
          return [] if yaml_output.nil? || yaml_output.strip.empty?

          docs = YAML.safe_load_stream(yaml_output, permitted_classes: [Symbol])
          docs.compact
              .select { |doc| doc.is_a?(Hash) && doc["kind"] == "CustomResourceDefinition" }
              .map { |doc| Kube::Cluster["CustomResourceDefinition"].new(doc) }
        end

        # The chart source for helm commands — either a local path or a remote ref.
        def source
          @path || @ref
        end

        # Version flag for remote charts. Local charts don't need --version.
        def version_flag
          @ref ? version : nil
        end

        def helm
          @cluster&.connection&.helm || Kube::Helm::Instance.new
        end

        def write_values_tempfile(values)
          tmpfile = Tempfile.new(["helm-values-", ".yaml"])
          tmpfile.write(values.to_yaml)
          tmpfile.flush
          tmpfile
        end

        def deep_symbolize_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              result[k.to_sym] = deep_symbolize_keys(v)
            end
          when Array
            obj.map { |v| deep_symbolize_keys(v) }
          else
            obj
          end
        end
    end
  end
end

if __FILE__ == $0
  require "minitest/autorun"

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
end
