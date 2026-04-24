# frozen_string_literal: true

require "bundler/setup"
require "scampi"
require "kube/cluster"

require_relative "middleware/stack"
require_relative "middleware/namespace"
require_relative "middleware/labels"
require_relative "middleware/annotations"
require_relative "middleware/resource_preset"
require_relative "middleware/security_context"
require_relative "middleware/pod_anti_affinity"
require_relative "middleware/service_for_deployment"
require_relative "middleware/ingress_for_service"
require_relative "middleware/hpa_for_deployment"

module Kube
  module Cluster
    # Base class for manifest middleware.
    #
    # Middleware receives the full manifest and mutates it in place.
    # Each middleware is responsible for iterating resources as needed.
    #
    # Transform example:
    #
    #   class AddTeamLabel < Middleware
    #     def call(manifest)
    #       manifest.resources.map! do |resource|
    #         h = resource.to_h
    #         h[:metadata][:labels][:"app.kubernetes.io/team"] = "platform"
    #         resource.rebuild(h)
    #       end
    #     end
    #   end
    #
    # Generative example:
    #
    #   class ServiceForDeployment < Middleware
    #     def call(manifest)
    #       generated = []
    #       manifest.resources.each do |resource|
    #         next unless resource.pod_bearing?
    #         generated << build_service_from(resource)
    #       end
    #       manifest.resources.concat(generated)
    #     end
    #   end
    #
    class Middleware
      DEFAULT_FILTER = -> (x) {true}

      def initialize(filter: DEFAULT_FILTER, **opts)
        @filter = filter
        @opts = opts
      end

      # Build an anonymous middleware class from a block.
      # The block becomes the +#call+ method and runs via
      # +instance_exec+, so +filter+, +deep_merge+, and
      # +@opts+ are all available inside it.
      #
      #   Middleware.build(filter: ->(r) { r.pod_bearing? }) do |manifest|
      #     manifest.resources.map! do |resource|
      #       filter(resource) do
      #         h = resource.to_h
      #         h[:metadata][:labels][:custom] = "yes"
      #         resource.rebuild(h)
      #       end
      #     end
      #   end
      #
      def self.build(**defaults, &block)
        Class.new(self) do
          define_method(:initialize) do |**overrides|
            super(**defaults, **overrides)
          end

          define_method(:call, &block)
        end
      end

      def filter(resource, &block)
        # In case super() wasn't called by the middleware.
        unless @filter.respond_to?(:call)
          @filter = DEFAULT_FILTER
        end

        # Usage:
        #   def call(manifest)
        #     manifest.resources.map! do |resource|
        #       filter(resource) do
        #         # ... middleware code here
        #       end
        #     end
        #   end
        if @filter.call(resource)
          instance_exec(&block)
        else
          resource
        end
      end

      # Override in subclasses. Receives the full manifest,
      # mutates it in place.
      def call(manifest)
      end

      private

        def deep_merge(base, overlay)
          base.merge(overlay) do |_key, old_val, new_val|
            if old_val.is_a?(Hash) && new_val.is_a?(Hash)
              deep_merge(old_val, new_val)
            else
              new_val
            end
          end
        end
    end
  end
end

test do
  Middleware = Kube::Cluster::Middleware

  # --- filter helper ----------------------------------------------------------

  it "filter_runs_block_when_filter_matches" do
    mw = Middleware.new(filter: ->(r) { true })
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    result = mw.filter(resource) { :ran }

    result.should == :ran
  end

  it "filter_returns_resource_when_filter_rejects" do
    mw = Middleware.new(filter: ->(r) { false })
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    result = mw.filter(resource) { :should_not_run }

    result.should == resource
  end

  it "filter_runs_block_by_default" do
    mw = Middleware.new
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    result = mw.filter(resource) { :ran }

    result.should == :ran
  end

  it "filter_passes_resource_to_filter_proc" do
    received = nil
    mw = Middleware.new(filter: ->(r) { received = r; true })
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    mw.filter(resource) { :ok }

    received.should == resource
  end

  it "filter_can_match_on_kind" do
    only_deployments = ->(r) { r.kind == "Deployment" }

    mw = Middleware.new(filter: only_deployments)
    deploy = Kube::Cluster["Deployment"].new { metadata.name = "web" }
    config = Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" }

    mw.filter(deploy) { :ran }.should == :ran
    mw.filter(config) { :ran }.should == config
  end

  it "filter_can_match_on_label" do
    only_labeled = ->(r) { r.label("app.kubernetes.io/name") == "web" }

    mw = Middleware.new(filter: only_labeled)
    labeled = Kube::Cluster["ConfigMap"].new {
      metadata.name = "cm"
      metadata.labels = { "app.kubernetes.io/name": "web" }
    }
    unlabeled = Kube::Cluster["ConfigMap"].new { metadata.name = "other" }

    mw.filter(labeled) { :ran }.should == :ran
    mw.filter(unlabeled) { :ran }.should == unlabeled
  end

  it "filter_can_match_on_pod_bearing" do
    only_pods = ->(r) { r.pod_bearing? }
    mw = Middleware.new(filter: only_pods)

    deploy = Kube::Cluster["Deployment"].new { metadata.name = "web" }
    config = Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" }

    mw.filter(deploy) { :ran }.should == :ran
    mw.filter(config) { :ran }.should == config
  end

  it "filter_block_has_access_to_middleware_instance" do
    mw = Middleware.new
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    # deep_merge is a private method on Middleware — the block should
    # be able to call it via instance_exec.
    result = mw.filter(resource) {
      deep_merge({ a: 1 }, { b: 2 })
    }

    result.should == { a: 1, b: 2 }
  end

  it "filter_recovers_when_super_was_not_called" do
    # Simulate a subclass that overrides initialize without calling super,
    # leaving @filter as nil.
    mw = Middleware.allocate
    resource = Kube::Cluster["ConfigMap"].new { metadata.name = "test" }

    result = mw.filter(resource) { :ran }

    result.should == :ran
  end

  # --- filter in a transform middleware (map! pattern) ------------------------

  it "filter_with_transform_middleware_skips_non_matching" do
    m = manifest(
      Kube::Cluster["Deployment"].new { metadata.name = "web" },
      Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" },
    )

    # A middleware that adds a label, but only to Deployments.
    mw = Middleware.new(filter: ->(r) { r.kind == "Deployment" })

    m.resources.map! do |resource|
      mw.filter(resource) do
        h = resource.to_h
        h[:metadata] ||= {}
        h[:metadata][:labels] = (h[:metadata][:labels] || {}).merge(tagged: "yes")
        resource.rebuild(h)
      end
    end

    m.resources[0].to_h.dig(:metadata, :labels, :tagged).should == "yes"
    m.resources[1].to_h.dig(:metadata, :labels, :tagged).should.be.nil
  end

  it "filter_with_transform_middleware_applies_to_all_by_default" do
    m = manifest(
      Kube::Cluster["Deployment"].new { metadata.name = "web" },
      Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" },
    )

    mw = Middleware.new

    m.resources.map! do |resource|
      mw.filter(resource) do
        h = resource.to_h
        h[:metadata] ||= {}
        h[:metadata][:labels] = (h[:metadata][:labels] || {}).merge(tagged: "yes")
        resource.rebuild(h)
      end
    end

    m.resources[0].to_h.dig(:metadata, :labels, :tagged).should == "yes"
    m.resources[1].to_h.dig(:metadata, :labels, :tagged).should == "yes"
  end

  # --- Middleware.build -------------------------------------------------------

  it "build_creates_middleware_from_block" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    klass = Middleware.build do |manifest|
      manifest.resources.map! do |resource|
        h = resource.to_h
        h[:metadata][:labels] = { injected: "yes" }
        resource.rebuild(h)
      end
    end
    klass.new.call(m)

    m.resources.first.to_h.dig(:metadata, :labels, :injected).should == "yes"
  end

  it "build_bakes_in_filter" do
    m = manifest(
      Kube::Cluster["Deployment"].new { metadata.name = "web" },
      Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" },
    )

    klass = Middleware.build(filter: ->(r) { r.kind == "Deployment" }) do |manifest|
      manifest.resources.map! do |resource|
        filter(resource) do
          h = resource.to_h
          h[:metadata][:labels] = (h[:metadata][:labels] || {}).merge(tagged: "yes")
          resource.rebuild(h)
        end
      end
    end
    klass.new.call(m)

    m.resources[0].to_h.dig(:metadata, :labels, :tagged).should == "yes"
    m.resources[1].to_h.dig(:metadata, :labels, :tagged).should.be.nil
  end

  it "build_has_access_to_deep_merge" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    klass = Middleware.build do |manifest|
      manifest.resources.map! do |resource|
        h = resource.to_h
        h[:metadata][:labels] = deep_merge({ a: 1 }, { b: 2 })
        resource.rebuild(h)
      end
    end
    klass.new.call(m)

    m.resources.first.to_h.dig(:metadata, :labels).should == { a: 1, b: 2 }
  end

  it "build_bakes_in_opts" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })

    klass = Middleware.build(team: "platform") do |manifest|
      manifest.resources.map! do |resource|
        h = resource.to_h
        h[:metadata][:labels] = { team: @opts[:team] }
        resource.rebuild(h)
      end
    end
    klass.new.call(m)

    m.resources.first.to_h.dig(:metadata, :labels, :team).should == "platform"
  end

  it "build_works_in_stack" do
    m = manifest(
      Kube::Cluster["Deployment"].new { metadata.name = "web" },
      Kube::Cluster["ConfigMap"].new { metadata.name = "cfg" },
    )

    stack = Middleware::Stack.new do
      use Middleware.build(filter: ->(r) { r.kind == "Deployment" }) { |manifest|
        manifest.resources.map! do |resource|
          filter(resource) do
            h = resource.to_h
            h[:metadata][:labels] = (h[:metadata][:labels] || {}).merge(custom: "from-build")
            resource.rebuild(h)
          end
        end
      }
    end
    stack.call(m)

    m.resources[0].to_h.dig(:metadata, :labels, :custom).should == "from-build"
    m.resources[1].to_h.dig(:metadata, :labels, :custom).should.be.nil
  end

  it "build_returns_a_class" do
    klass = Middleware.build { |manifest| }

    klass.should.be.kind_of(Class)
    (klass < Middleware).should == true
  end

  it "build_noop_base_class_without_block" do
    m = manifest(Kube::Cluster["ConfigMap"].new { metadata.name = "test" })
    original = m.resources.first.to_h.dup

    Middleware.new.call(m)

    m.resources.first.to_h.should == original
  end

  # --- filter in a generative middleware (each pattern) -----------------------

  it "filter_with_generative_middleware_skips_non_matching" do
    m = manifest(
      Kube::Cluster["Deployment"].new {
        metadata.name = "web"
        metadata.labels = { "app.kubernetes.io/name": "web" }
      },
      Kube::Cluster["Deployment"].new {
        metadata.name = "worker"
        metadata.labels = { "app.kubernetes.io/name": "worker" }
      },
    )

    only_web = ->(r) { r.label("app.kubernetes.io/name") == "web" }
    mw = Middleware.new(filter: only_web)

    generated = []
    m.resources.each do |resource|
      mw.filter(resource) do
        generated << Kube::Cluster["ConfigMap"].new {
          metadata.name = "generated-for-#{resource.to_h.dig(:metadata, :name)}"
        }
      end
    end
    m.resources.concat(generated)

    m.resources.size.should == 3
    m.resources.last.to_h.dig(:metadata, :name).should == "generated-for-web"
  end

  private

    def manifest(*resources)
      m = Kube::Cluster::Manifest.new
      resources.each { |r| m << r }
      m
    end
end
