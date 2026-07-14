# frozen_string_literal: true

require "bundler/setup"
require "kube/schema"
require "active_support/core_ext/string/inflections"

require_relative "../kube/errors"
require_relative "cluster/version"
require_relative "cluster/script_command"
require 'kube/ctl'
require_relative 'helm/repo'

module Kube
  def self.cluster
    Cluster
  end

  module Cluster
    def self.connect(kubeconfig:)
      Instance.new(kubeconfig: kubeconfig)
    end

    # Internal table mapping a bare kind to the group/version/Kind it should
    # resolve to. Consulted first by Kube::Cluster.[] so a bare lookup lands on
    # a pinned version instead of whatever the schema registry defaults to.
    def self.resolve_table
      @resolve_table ||= {}
    end

    # Configure kind resolution:
    #
    #   Kube::Cluster.config do
    #     resolve "Perses", to: "perses.dev/v1alpha2/Perses"
    #   end
    #
    # Ordering matters: Kube::Cluster.[] memoizes per kind, and the Standard
    # classes bind their superclass at definition time (e.g.
    # `class Perses < Kube::Cluster["Perses"]`). A resolve therefore only takes
    # effect for kinds looked up afterwards — so configure before requiring any
    # kube/cluster/standard class. If Standard is already loaded, warn: its
    # classes have already bound their (now stale) superclasses.
    def self.config(&block)
      if const_defined?(:Standard, false)
        warn "Kube::Cluster::Standard was loaded before Kube::Cluster.config — " \
          "resolve overrides will not affect the already-bound Standard classes."
      end
      Config.instance_eval(&block) if block
      Config
    end

    module Config
      module_function

      def resolve(kind, to:)
        Kube::Cluster.resolve_table[kind] = to
      end
    end

    # Returns an anonymous subclass of Kube::Cluster::Resource for the
    # given Kubernetes kind, mirroring Kube::Schema[kind] but with
    # dirty tracking, persistence, and resource helper methods.
    #
    #   Kube::Cluster["Deployment"].new { metadata.name = "web" }
    #
    def self.[](kind)
      kind = resolve_table.fetch(kind, kind)
      @resource_classes ||= {}
      @resource_classes[kind] ||= begin
        schema_class = Kube::Schema[kind]
        Class.new(Resource) do
          @schema            = schema_class.schema
          @defaults          = schema_class.defaults
          @schema_properties = schema_class.schema_properties

          def self.schema            = @schema            || superclass.schema
          def self.defaults          = @defaults          || superclass.defaults
          def self.schema_properties = @schema_properties || superclass.schema_properties
        end
      end
    end
  end
end

require "kube/cluster/middleware"
require "kube/cluster/resource/dirty_tracking"
require "kube/cluster/resource/persistence"

# Kind resolution overrides. Registered here, at load time, so the pins are in
# place before a project requires any kube/cluster/standard class (those bind
# Kube::Cluster[kind] at definition time). The standard tree is deliberately not
# auto-required below — projects require the specific classes they use.
Kube::Cluster.config do
  # Built-in Kubernetes kinds.
  resolve "ConfigMap",                to: "v1/ConfigMap"
  resolve "PersistentVolumeClaim",    to: "v1/PersistentVolumeClaim"
  resolve "Secret",                   to: "v1/Secret"
  resolve "Service",                  to: "v1/Service"
  resolve "ServiceAccount",           to: "v1/ServiceAccount"
  resolve "DaemonSet",                to: "apps/v1/DaemonSet"
  resolve "Deployment",               to: "apps/v1/Deployment"
  resolve "CronJob",                  to: "batch/v1/CronJob"
  resolve "Job",                      to: "batch/v1/Job"
  resolve "Role",                     to: "rbac.authorization.k8s.io/v1/Role"
  resolve "RoleBinding",              to: "rbac.authorization.k8s.io/v1/RoleBinding"
  resolve "CustomResourceDefinition", to: "apiextensions.k8s.io/v1/CustomResourceDefinition"

  # Metacontroller.
  resolve "CompositeController",      to: "metacontroller.k8s.io/v1alpha1/CompositeController"
  resolve "DecoratorController",      to: "metacontroller.k8s.io/v1alpha1/DecoratorController"

  # CloudNativePG.
  resolve "Cluster",                  to: "postgresql.cnpg.io/v1/Cluster"
  resolve "Database",                 to: "postgresql.cnpg.io/v1/Database"

  # External Secrets Operator.
  resolve "ExternalSecret",           to: "external-secrets.io/v1/ExternalSecret"

  # KubeVirt.
  resolve "VirtualMachine",           to: "kubevirt.io/v1/VirtualMachine"

  # CDI (Containerized Data Importer).
  resolve "DataVolume",               to: "cdi.kubevirt.io/v1beta1/DataVolume"

  # k3s HelmChart.
  resolve "HelmChart",                to: "helm.cattle.io/v1/HelmChart"

  # VictoriaMetrics operator.
  resolve "VLAgent",                  to: "operator.victoriametrics.com/v1/VLAgent"
  resolve "VLCluster",                to: "operator.victoriametrics.com/v1/VLCluster"
  resolve "VLogs",                    to: "operator.victoriametrics.com/v1beta1/VLogs"
  resolve "VLSingle",                 to: "operator.victoriametrics.com/v1/VLSingle"
  resolve "VMAgent",                  to: "operator.victoriametrics.com/v1beta1/VMAgent"
  resolve "VMAlert",                  to: "operator.victoriametrics.com/v1beta1/VMAlert"
  resolve "VMAlertmanager",           to: "operator.victoriametrics.com/v1beta1/VMAlertmanager"
  resolve "VMAlertmanagerConfig",     to: "operator.victoriametrics.com/v1beta1/VMAlertmanagerConfig"
  resolve "VMAnomaly",                to: "operator.victoriametrics.com/v1/VMAnomaly"
  resolve "VMAnomalyConfig",          to: "operator.victoriametrics.com/v1/VMAnomalyConfig"
  resolve "VMAuth",                   to: "operator.victoriametrics.com/v1beta1/VMAuth"
  resolve "VMCluster",                to: "operator.victoriametrics.com/v1beta1/VMCluster"
  resolve "VMDistributed",            to: "operator.victoriametrics.com/v1alpha1/VMDistributed"
  resolve "VMNodeScrape",             to: "operator.victoriametrics.com/v1beta1/VMNodeScrape"
  resolve "VMPodScrape",              to: "operator.victoriametrics.com/v1beta1/VMPodScrape"
  resolve "VMProbe",                  to: "operator.victoriametrics.com/v1beta1/VMProbe"
  resolve "VMRule",                   to: "operator.victoriametrics.com/v1beta1/VMRule"
  resolve "VMScrapeConfig",           to: "operator.victoriametrics.com/v1beta1/VMScrapeConfig"
  resolve "VMServiceScrape",          to: "operator.victoriametrics.com/v1beta1/VMServiceScrape"
  resolve "VMSingle",                 to: "operator.victoriametrics.com/v1beta1/VMSingle"
  resolve "VMStaticScrape",           to: "operator.victoriametrics.com/v1beta1/VMStaticScrape"
  resolve "VMUser",                   to: "operator.victoriametrics.com/v1beta1/VMUser"
  resolve "VTCluster",                to: "operator.victoriametrics.com/v1/VTCluster"
  resolve "VTSingle",                 to: "operator.victoriametrics.com/v1/VTSingle"

  # Gateway API — pin to the stable v1 group/version.
  resolve "GatewayClass",             to: "gateway.networking.k8s.io/v1/GatewayClass"
  resolve "Gateway",                  to: "gateway.networking.k8s.io/v1/Gateway"
  resolve "HTTPRoute",                to: "gateway.networking.k8s.io/v1/HTTPRoute"
  resolve "GRPCRoute",                to: "gateway.networking.k8s.io/v1/GRPCRoute"
  resolve "ReferenceGrant",           to: "gateway.networking.k8s.io/v1/ReferenceGrant"

  # Perses operator — pin to v1alpha2 (bare kind defaults to deprecated v1alpha1).
  resolve "Perses",                   to: "perses.dev/v1alpha2/Perses"
  resolve "PersesDashboard",          to: "perses.dev/v1alpha2/PersesDashboard"
  resolve "PersesDatasource",         to: "perses.dev/v1alpha2/PersesDatasource"
  resolve "PersesGlobalDatasource",   to: "perses.dev/v1alpha2/PersesGlobalDatasource"
end

standard_root = "#{__dir__}/cluster/standard"
Dir.glob("#{__dir__}/cluster/**/*.rb").sort.each do |path|
  # The standard/ tree is opt-in — via `require "kube/cluster/standard"` or a
  # specific class — so that resolve overrides can be configured beforehand.
  # Skip both the tree and its aggregator loader (cluster/standard.rb).
  next if path == "#{standard_root}.rb" || path.start_with?("#{standard_root}/")

  require path
end

__END__

# Every Standard class binds its superclass at load time with a bare kind, e.g.
# `class Perses < Kube::Cluster["Perses"]`. A bare kind resolves to whatever
# version the schema registry lists first — sometimes a deprecated one (Perses
# defaulted to v1alpha1) — so each such kind must be pinned in the resolve table
# above. This fails if any bare kind under kube/cluster/standard is unpinned.
describe "Kube::Cluster resolve table" do
  it "pins every bare kind referenced under kube/cluster/standard" do
    cluster_rb = Kube::Cluster.method(:[]).source_location.first
    std_dir    = File.join(File.dirname(cluster_rb), "cluster", "standard")

    # kind => ["relative/file.rb:lineno", ...], scanning only real code (the
    # section before each file's own __END__), skipping commented-out classes.
    referenced = {}
    Dir.glob("#{std_dir}/**/*.rb").sort.each do |file|
      head = File.read(file).split(/^__END__$\n?/, 2).first
      head.each_line.with_index(1) do |line, lineno|
        next if line =~ /\A\s*#/
        line.scan(/Kube::Cluster\[\s*['"]([^'"]+)['"]\s*\]/) do |(ref)|
          next if ref.include?("/") # already a fully-qualified GVK
          (referenced[ref] ||= []) << "#{file.sub("#{std_dir}/", "")}:#{lineno}"
        end
      end
    end

    table   = Kube::Cluster.resolve_table
    missing = referenced.reject { |kind, _| table.key?(kind) }

    unless missing.empty?
      report = missing.sort.map { |kind, locs| "  #{kind}  (#{locs.join(", ")})" }.join("\n")
      raise "Bare kinds under kube/cluster/standard missing from the resolve table:\n#{report}"
    end

    missing.empty?.should == true
  end
end

