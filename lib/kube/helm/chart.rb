# frozen_string_literal: true

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
