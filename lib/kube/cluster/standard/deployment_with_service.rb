# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      class DeploymentWithService < Kube::Cluster::Manifest
        def initialize(
          name:,
          image:,
          port:,
          namespace: 'default',
          env: {},
          command: nil,
          init_containers: [],
          security_context: nil,
          pod_security_context: nil,
          volume_mounts: {},
          service_port: nil,
          stdin: false,
          tty: false,
          &block
        )
          @_limits = {}
          @_probes = {}

          processed_env     = EnvProcessing.process(env)
          processed_volumes = VolumeProcessing.process(volume_mounts)

          service_ports = Array(service_port || port)

          service = Kube::Cluster::Standard::Service.new(
            name: name,
            namespace: namespace,
            ports: service_ports
          )

          deployment = Kube::Cluster['Deployment'].new do
            metadata.name = name
            metadata.namespace = namespace
            metadata.labels = { 'app' => name }

            spec.replicas = 1
            spec.selector.matchLabels = { 'app' => name }

            spec.template.metadata.labels = { 'app' => name }
            spec.template.spec.securityContext = pod_security_context if pod_security_context

            container = {
              name: name,
              image: image,
              ports: [{ name: 'http', containerPort: port, protocol: 'TCP' }],
              env: processed_env
            }
            container[:command] = command if command
            container[:securityContext] = security_context if security_context
            container[:volumeMounts] = processed_volumes[:volume_mounts] unless processed_volumes[:volume_mounts].empty?

            # Keep stdin/tty open so the pod can be `kubectl attach`-ed for
            # interactive flows (e.g. an OAuth proxy that prompts for a
            # redirect URL on first authorization).
            container[:stdin] = true if stdin
            container[:tty] = true if tty

            spec.template.spec.containers = [container]
            spec.template.spec.initContainers = init_containers unless init_containers.empty?
            spec.template.spec.volumes = processed_volumes[:volumes] unless processed_volumes[:volumes].empty?
          end

          super(deployment, service)

          instance_exec(&block) if block

          deployment = _apply_limits(deployment)
          _apply_probes(deployment)
        end

        def limits
          @_limits
        end

        def probes
          @_probes
        end

        private

        def _apply_limits(deployment)
          return deployment if @_limits.empty?

          container = deployment.to_h[:spec][:template][:spec][:containers][0]
          resources = {}

          @_limits.each do |resource_type, mapping|
            mapping.each do |request, limit|
              resources[:requests] ||= {}
              resources[:requests][resource_type] = request.to_s

              if limit != Float::INFINITY
                resources[:limits] ||= {}
                resources[:limits][resource_type] = limit.to_s
              end
            end
          end

          container[:resources] = resources
          h = deployment.to_h
          h[:spec][:template][:spec][:containers][0] = container
          _replace(deployment, deployment.rebuild(h))
        end

        def _apply_probes(deployment)
          return deployment if @_probes.empty?
          return deployment unless @_probes[:url]

          container = deployment.to_h[:spec][:template][:spec][:containers][0]
          url = @_probes[:url]

          if @_probes[:liveness]
            delay, period = @_probes[:liveness].first
            container[:livenessProbe] = {
              httpGet: url,
              initialDelaySeconds: delay,
              periodSeconds: period,
              timeoutSeconds: 5
            }
          end

          if @_probes[:readiness]
            delay, period = @_probes[:readiness].first
            container[:readinessProbe] = {
              httpGet: url,
              initialDelaySeconds: delay,
              periodSeconds: period,
              timeoutSeconds: 5
            }
          end

          h = deployment.to_h
          h[:spec][:template][:spec][:containers][0] = container
          _replace(deployment, deployment.rebuild(h))
        end

        # rebuild returns a new resource; swap it into this manifest so the
        # change actually lands in the rendered output.
        def _replace(old, rebuilt)
          @resources[@resources.index(old)] = rebuilt
          rebuilt
        end
      end
    end
  end
end

test do
  describe "DeploymentWithService" do
    it "initializes without error" do
      Kube::Cluster::Standard::DeploymentWithService
        .new(
          name: "pointless-ruby-container",
          image: "ruby/ruby",
          port: 3000,
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end

    it "sets stdin/tty on the container when requested" do
      yaml = Kube::Cluster::Standard::DeploymentWithService
        .new(
          name: "interactive",
          image: "ruby/ruby",
          port: 3000,
          stdin: true,
          tty: true,
        )
        .to_yaml

      yaml.include?("stdin: true").should == true
      yaml.include?("tty: true").should == true
    end

    it "renders limits from the block DSL" do
      yaml = Kube::Cluster::Standard::DeploymentWithService
        .new(
          name: "limited",
          image: "ruby/ruby",
          port: 3000,
        ) {
          limits.cpu    = { "500m" => Float::INFINITY }
          limits.memory = { "1Gi" => "2Gi" }
        }
        .to_yaml

      yaml.include?("cpu: 500m").should == true
      yaml.include?("memory: 1Gi").should == true
      yaml.include?("memory: 2Gi").should == true
      # Infinity means request-only — no cpu limit is emitted.
      yaml.scan(/cpu:/).length.should == 1
    end

    it "renders probes from the block DSL" do
      yaml = Kube::Cluster::Standard::DeploymentWithService
        .new(
          name: "probed",
          image: "ruby/ruby",
          port: 3000,
        ) {
          probes.url       = { path: "/healthz", port: "http" }
          probes.liveness  = { 120 => 30 }
          probes.readiness = { 60 => 10 }
        }
        .to_yaml

      yaml.include?("livenessProbe").should == true
      yaml.include?("readinessProbe").should == true
      yaml.include?("path: \"/healthz\"").should == true
      yaml.include?("initialDelaySeconds: 120").should == true
      yaml.include?("initialDelaySeconds: 60").should == true
    end

    it "renders limits and probes together" do
      yaml = Kube::Cluster::Standard::DeploymentWithService
        .new(
          name: "both",
          image: "ruby/ruby",
          port: 3000,
        ) {
          limits.memory    = { "1Gi" => "2Gi" }
          probes.url       = { path: "/healthz", port: "http" }
          probes.readiness = { 5 => 5 }
        }
        .to_yaml

      # The probe pass must not clobber the limits pass (each rebuilds the
      # deployment; the second must start from the first's result).
      yaml.include?("memory: 2Gi").should == true
      yaml.include?("readinessProbe").should == true
    end
  end
end
