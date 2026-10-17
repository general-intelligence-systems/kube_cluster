# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"
require "tempfile"
require "yaml"

module Kube
  module Helm
    # Represents a Helm Chart.yaml as a Ruby object.
    #
    # @example Virtual chart (just metadata, no templates)
    #   chart = Kube::Helm::Chart.new {
    #     name = "my-app"
    #     version = "1.0.0"
    #     appVersion = "3.4.5"
    #   }
    #
    # @example Load from a local chart directory
    #   chart = Kube::Helm::Chart.open("./charts/my-app")
    #   manifest = chart.apply_values({ "replicaCount" => 3 })
    #
    # @example From a remote repo
    #   manifest = Kube::Helm::Repo
    #     .new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #     .fetch("nginx", version: "18.1.0")
    #     .apply_values({ "replicaCount" => 3 })
    class Chart
      attr_reader :path, :ref, :cluster

      # Open a chart from a local directory.
      # @parameter path [String] path to the chart directory.
      # @parameter cluster [Kube::Cluster::Instance, nil] an optional cluster connection.
      # @returns [Chart] the chart, with path set for local helm commands.
      def self.open(path, cluster: nil)
        chart_file = File.join(path, "Chart.yaml")
        unless File.exist?(chart_file)
          raise Kube::Error, "No Chart.yaml found at #{path}"
        end

        yaml = YAML.safe_load_file(chart_file)
        new(yaml, path: path, cluster: cluster)
      end

      # @parameter data [Hash] Chart.yaml content, string or symbol keyed.
      # @parameter path [String, nil] a filesystem path to a local chart directory.
      # @parameter ref [String, nil] a chart reference for helm commands on remote charts.
      # @parameter cluster [Kube::Cluster::Instance, nil] an optional cluster connection.
      def initialize(data = {}, path: nil, ref: nil, cluster: nil, &block)
        @data    = deep_symbolize_keys(data)
        @path    = path
        @ref     = ref
        @cluster = cluster
        if block_given?
          @data.instance_exec(&block)
        end
      end

      def name         = @data[:name]
      def version      = @data[:version]
      def app_version  = @data[:appVersion]
      def description  = @data[:description]
      def type         = @data[:type]
      def dependencies = @data[:dependencies] || []

      # Renders the chart templates with values applied.
      # @parameter values [Hash] values to apply to the chart templates.
      # @parameter release [String, nil] a release name, defaulting to the chart name.
      # @parameter namespace [String, nil] a namespace for the rendered resources.
      # @returns [Kube::Schema::Manifest] the rendered resources, via `helm template`.
      def apply_values(values, release: nil, namespace: nil)
        unless source
          raise Kube::Error, "No chart source"
        end

        release_name = release || name
        source_ref = source
        ver = version_flag

        cmd = helm.call { template.(release_name).(source_ref).include_crds(true) }
        if ver
          cmd = cmd.version(ver)
        end
        if namespace
          cmd = cmd.namespace(namespace)
        end

        if values.is_a?(Hash) && values.any?
          tmpfile = write_values_tempfile(values)
          cmd = cmd.f(tmpfile.path)
        end

        Kube::Schema::Manifest.parse(helm.run(cmd.to_s))
      end

      # Show the chart's default values.
      # @returns [Hash] the default values, via `helm show values`.
      def show_values
        unless source
          raise Kube::Error, "No chart source"
        end

        source_ref = source
        ver = version_flag
        cmd = helm.call { show.values.(source_ref) }
        if ver
          cmd = cmd.version(ver)
        end

        YAML.safe_load(helm.run(cmd.to_s), permitted_classes: [Symbol]) || {}
      end

      # The chart's CRDs, as typed CustomResourceDefinition objects.
      #
      # @example
      #   chart.crds.each do |crd|
      #     s = crd.to_json_schema
      #     Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
      #   end
      #
      # @returns [Array(Kube::Cluster::CustomResourceDefinition)] the chart's CRDs.
      def crds
        unless source
          raise Kube::Error, "No chart source"
        end

        results = crds_from_show
        if results.empty?
          results = crds_from_template
        end
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
          if ver
            cmd = cmd.version(ver)
          end

          yaml_output = helm.run(cmd.to_s)
          parse_crds(yaml_output)
        end

        def crds_from_template
          source_ref = source
          ver = version_flag
          release_name = name || "crds"

          cmd = helm.call { template.(release_name).(source_ref).include_crds(true) }
          if ver
            cmd = cmd.version(ver)
          end
          cmd = cmd.set("installCRDs=true")

          yaml_output = helm.run(cmd.to_s)
          parse_crds(yaml_output)
        end

        def parse_crds(yaml_output)
          if yaml_output.nil? || yaml_output.strip.empty?
            []
          else
            docs = YAML.safe_load_stream(split_documents(yaml_output), permitted_classes: [Symbol])
            docs.compact
                .select { |doc| doc.is_a?(Hash) && doc["kind"] == "CustomResourceDefinition" }
                .map { |doc| Kube::Cluster["CustomResourceDefinition"].new(doc) }
          end
        end

        # Splits concatenated CRD YAML at each top-level `apiVersion:`.
        # @parameter yaml_output [String] the raw `helm show crds` output, which
        #   joins several CRDs without a "---", silently losing all but the last.
        # @returns [String] the same YAML, with "---" before each document.
        def split_documents(yaml_output)
          yaml_output.gsub(/\n(?=apiVersion:)/, "\n---\n")
        end

        # The chart source for helm commands.
        # @returns [String, nil] the local path, the remote ref, or nil.
        def source
          @path || @ref
        end

        # Version flag for remote charts. Local charts don't need --version.
        # @returns [String, nil] the chart version, or nil for local charts.
        def version_flag
          @ref ? version : nil
        end

        def helm
          @cluster&.connection&.helm || Kube::Helm::Instance.new
        end

        def write_values_tempfile(values)
          Tempfile.new(["helm-values-", ".yaml"]).tap do |tmpfile|
            tmpfile.write(deep_stringify_keys(values).to_yaml)
            tmpfile.flush
          end
        end

        def deep_stringify_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              result[k.to_s] = deep_stringify_keys(v)
            end
          when Array
            obj.map { |v| deep_stringify_keys(v) }
          else
            obj
          end
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

__END__

# ── initialization ────────────────────────────────────────────────────

it "initializes_with_data_hash" do
  chart = Kube::Helm::Chart.new({ "name" => "my-app", "version" => "1.0.0", "appVersion" => "2.5.0" })
  chart.name.should == "my-app"
end

it "initializes_with_block" do
  chart = Kube::Helm::Chart.new {
    self.name = "my-app"
    self.version = "1.0.0"
    self.appVersion = "2.5.0"
    self.description = "A test chart"
  }

  chart.description.should == "A test chart"
end

it "initializes_empty" do
  chart = Kube::Helm::Chart.new
  chart.dependencies.should == []
end

it "initializes_with_path" do
  chart = Kube::Helm::Chart.new({ "name" => "x" }, path: "/tmp/charts/x")
  chart.path.should == "/tmp/charts/x"
end

it "initializes_with_cluster" do
  cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
  chart = Kube::Helm::Chart.new({ "name" => "x" }, cluster: cluster)
  chart.cluster.should == cluster
end

# ── Chart.open ───────────────────────────────────────────────────────

it "open_reads_chart_yaml" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), {
      "name" => "test-chart",
      "version" => "0.1.0",
      "appVersion" => "1.0.0",
      "description" => "A test chart",
      "type" => "application",
    }.to_yaml)

    chart = Kube::Helm::Chart.open(dir)
    chart.name.should == "test-chart"
  end
end

it "open_raises_without_chart_yaml" do
  Dir.mktmpdir do |dir|
    lambda { Kube::Helm::Chart.open(dir) }.should.raise Kube::Error
  end
end

it "open_with_cluster" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "x", "version" => "1.0.0" }.to_yaml)
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")

    chart = Kube::Helm::Chart.open(dir, cluster: cluster)
    chart.cluster.should == cluster
  end
end

# ── to_s ──────────────────────────────────────────────────────────────

it "to_s_with_version" do
  chart = Kube::Helm::Chart.new({ "name" => "nginx", "version" => "18.1.0" })
  chart.to_s.should == "nginx:18.1.0"
end

it "to_s_without_version" do
  chart = Kube::Helm::Chart.new({ "name" => "nginx" })
  chart.to_s.should == "nginx"
end

# ── apply_values ─────────────────────────────────────────────────────

it "apply_values_raises_without_source" do
  chart = Kube::Helm::Chart.new({ "name" => "my-app" })
  lambda { chart.apply_values({ "replicaCount" => 3 }) }.should.raise Kube::Error
end

it "apply_values_builds_correct_command" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({ "replicaCount" => 3 })
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include dir
  end
end

it "apply_values_with_custom_release" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({}, release: "custom-release")
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "custom-release"
  end
end

it "apply_values_with_namespace" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({}, namespace: "production")
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "--namespace=production"
  end
end

it "apply_values_returns_manifest" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    stub_yaml = [
      { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } },
      { "kind" => "Service", "apiVersion" => "v1", "metadata" => { "name" => "web" } },
    ].map(&:to_yaml).join("")

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |_cmd| stub_yaml }
    begin
      result = chart.apply_values({ "replicaCount" => 3 })
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    result.should.be.instance_of Kube::Schema::Manifest
  end
end

it "apply_values_defaults_release_to_chart_name" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "nginx", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({})
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "nginx"
  end
end

it "apply_values_stringifies_symbol_keys_in_values_file" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    tmpfile = chart.send(:write_values_tempfile, { k8sDistribution: "k3s", nested: { setup: [] } })
    contents = File.read(tmpfile.path)
    contents.should.include "k8sDistribution"
    contents.should.not.include ":k8sDistribution"
    contents.should.include "nested"
    contents.should.not.include ":nested"
  end
end

# ── show_values ──────────────────────────────────────────────────────

it "show_values" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "replicaCount" => 1, "service" => { "type" => "ClusterIP" } }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      result = chart.show_values
      result["replicaCount"].should == 1
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end
  end
end

it "show_values_raises_without_source" do
  chart = Kube::Helm::Chart.new({ "name" => "my-app" })
  lambda { chart.show_values }.should.raise Kube::Error
end

# ── crds ─────────────────────────────────────────────────────────────

it "crds_returns_custom_resource_definition_objects" do
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

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |_cmd| stub_yaml }
    begin
      result = chart.crds
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    result.length.should == 1
  end
end

it "crds_raises_without_source" do
  chart = Kube::Helm::Chart.new({ "name" => "my-app" })
  lambda { chart.crds }.should.raise Kube::Error
end

# ── cluster scoping ──────────────────────────────────────────────────

it "apply_values_uses_cluster_helm_instance" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.open(dir, cluster: cluster)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    helm = cluster.connection.helm
    original = helm.method(:run)
    helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({ "foo" => "bar" })
    ensure
      helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "template"
  end
end

it "show_values_uses_cluster_helm_instance" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    cluster = Kube::Cluster.connect(kubeconfig: "/tmp/test-kubeconfig")
    chart = Kube::Helm::Chart.open(dir, cluster: cluster)

    captured_cmd = nil
    stub_yaml = { "replicaCount" => 1 }.to_yaml

    helm = cluster.connection.helm
    original = helm.method(:run)
    helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.show_values
    ensure
      helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.include "show"
  end
end

# ── remote chart (ref-based) ─────────────────────────────────────────

it "initializes_with_ref" do
  chart = Kube::Helm::Chart.new({ "name" => "nginx", "version" => "18.1.0" }, ref: "bitnami/nginx")
  chart.ref.should == "bitnami/nginx"
end

it "apply_values_with_ref_uses_ref_and_version" do
  chart = Kube::Helm::Chart.new(
    { "name" => "nginx", "version" => "18.1.0" },
    ref: "bitnami/nginx"
  )

  captured_cmd = nil
  stub_yaml = { "kind" => "Deployment", "apiVersion" => "apps/v1", "metadata" => { "name" => "web" } }.to_yaml

  original = Kube::Helm.method(:run)
  Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
  begin
    chart.apply_values({ "replicaCount" => 3 })
  ensure
    Kube::Helm.define_singleton_method(:run, original)
  end

  captured_cmd.should.include "--version=18.1.0"
end

it "apply_values_with_path_does_not_add_version_flag" do
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "Chart.yaml"), { "name" => "my-app", "version" => "1.0.0" }.to_yaml)
    chart = Kube::Helm::Chart.open(dir)

    captured_cmd = nil
    stub_yaml = { "kind" => "Pod", "apiVersion" => "v1" }.to_yaml

    original = Kube::Helm.method(:run)
    Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
    begin
      chart.apply_values({})
    ensure
      Kube::Helm.define_singleton_method(:run, original)
    end

    captured_cmd.should.not.include "--version"
  end
end

it "show_values_with_ref" do
  chart = Kube::Helm::Chart.new(
    { "name" => "nginx", "version" => "18.1.0" },
    ref: "bitnami/nginx"
  )

  captured_cmd = nil
  stub_yaml = { "replicaCount" => 1 }.to_yaml

  original = Kube::Helm.method(:run)
  Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
  begin
    chart.show_values
  ensure
    Kube::Helm.define_singleton_method(:run, original)
  end

  captured_cmd.should.include "--version=18.1.0"
end

it "crds_with_ref" do
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
  original = Kube::Helm.method(:run)
  Kube::Helm.define_singleton_method(:run) { |cmd| captured_cmd = cmd; stub_yaml }
  begin
    result = chart.crds
    result.length.should == 1
  ensure
    Kube::Helm.define_singleton_method(:run, original)
  end
end
