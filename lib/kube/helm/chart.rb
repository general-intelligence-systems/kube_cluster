# frozen_string_literal: true

require "tempfile"
require "yaml"

module Kube
  module Helm
    # A reference to a specific Helm chart that can be rendered into
    # a Manifest of typed Kubernetes Resource objects.
    #
    # Chart objects are created via Repo#chart -- you don't normally
    # instantiate them directly. The +cluster+ connection (if any) is
    # propagated automatically from the Repo.
    #
    #   repo  = Kube::Helm::Repo.new("bitnami", url: "https://charts.bitnami.com/bitnami")
    #   chart = repo.chart("nginx", version: "18.1.0")
    #
    #   manifest = chart.template(
    #     release:   "my-nginx",
    #     namespace: "production",
    #     values:    { "replicaCount" => 3 }
    #   )
    #
    #   manifest.each { |r| puts "#{r.kind}: #{r.metadata.name}" }
    #
    class Chart
      attr_reader :ref, :version, :cluster

      # @param ref [String] the chart reference ("repo/chart" or "oci://host/path/chart")
      # @param version [String, nil] version constraint
      # @param cluster [Kube::Cluster::Instance, nil] optional cluster connection
      #   for kubeconfig scoping
      def initialize(ref, version: nil, cluster: nil)
        @ref     = ref
        @version = version
        @cluster = cluster
      end

      # Render the chart with values applied via `helm template`.
      #
      # Returns a Kube::Schema::Manifest populated with typed Resource objects.
      #
      # @param release [String] the release name
      # @param namespace [String, nil] Kubernetes namespace for the rendered resources
      # @param values [Hash, nil] values to apply (serialized to a temp YAML file)
      # @param values_file [String, nil] path to an existing values YAML file
      # @return [Kube::Schema::Manifest]
      def template(release:, namespace: nil, values: nil, values_file: nil)
        cmd = build_template_command(release, namespace, values, values_file)
        yaml_output = helm_run(cmd)
        Kube::Schema::Manifest.parse(yaml_output)
      end

      # Download the chart archive to a local directory.
      #
      # @param destination [String] directory to download into
      # @param untar [Boolean] whether to untar the chart (default: true)
      # @return [String] command output
      def pull(destination:, untar: true)
        parts = ["pull", @ref]
        parts << "--version #{@version}" if @version
        parts << "--destination #{destination}"
        parts << "--untar" if untar

        helm_run(parts.join(" "))
      end

      # Show the chart's default values.
      #
      # @return [Hash] the default values as a Ruby hash
      def show_values
        parts = ["show values", @ref]
        parts << "--version #{@version}" if @version

        yaml_output = helm_run(parts.join(" "))
        YAML.safe_load(yaml_output, permitted_classes: [Symbol]) || {}
      end

      # Return the chart's CRDs as Kube::Cluster::CustomResourceDefinition objects.
      #
      # Uses `helm show crds` to fetch the raw CRD documents, then wraps
      # each in a CustomResourceDefinition instance with a #to_json_schema
      # method for registration.
      #
      #   chart.crds.each do |crd|
      #     s = crd.to_json_schema
      #     Kube::Schema.register(s[:kind], schema: s[:schema], api_version: s[:api_version])
      #   end
      #
      # @return [Array<Kube::Cluster::CustomResourceDefinition>]
      def crds
        parts = ["show crds", @ref]
        parts << "--version #{@version}" if @version

        yaml_output = helm_run(parts.join(" "))

        docs = if YAML.respond_to?(:safe_load_stream)
                 YAML.safe_load_stream(yaml_output, permitted_classes: [Symbol])
               else
                 YAML.load_stream(yaml_output)
               end

        docs.compact
            .select { |doc| doc.is_a?(Hash) && doc["kind"] == "CustomResourceDefinition" }
            .map { |doc| Kube::Cluster["CustomResourceDefinition"].new(doc) }
      end

      def to_s
        @version ? "#{@ref}:#{@version}" : @ref
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

        def build_template_command(release, namespace, values, values_file)
          parts = ["template", release, @ref]
          parts << "--version #{@version}" if @version
          parts << "--namespace #{namespace}" if namespace

          if values.is_a?(Hash) && values.any?
            tmpfile = write_values_tempfile(values)
            parts << "--values #{tmpfile.path}"
          end

          parts << "--values #{values_file}" if values_file

          parts.join(" ")
        end

        # Serialize a values hash to a Tempfile.
        # The Tempfile is kept open (not unlinked) so Helm can read it.
        # Ruby's GC will clean it up when the reference is released.
        def write_values_tempfile(values)
          tmpfile = Tempfile.new(["helm-values-", ".yaml"])
          tmpfile.write(values.to_yaml)
          tmpfile.flush
          tmpfile
        end
    end
  end
end
