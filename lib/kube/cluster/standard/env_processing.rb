# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module EnvProcessing
        # Convert an env hash into a Kubernetes env array.
        #
        # String/numeric values become plain env vars:
        #   "FOO" => "bar"  =>  { name: "FOO", value: "bar" }
        #
        # ExternalSecret::TemplateRef values become secretKeyRef env vars
        # and register the template entry on the ExternalSecret:
        #   "FOO" => secret.template("{{ .bar }}")
        #     =>  { name: "FOO", valueFrom: { secretKeyRef: { name: "secret-name", key: "FOO" } } }
        #
        # Secret::KeyRef values reference an existing secret's key directly
        # (the same Secret.new(name:).key(...) form used by volume_mounts):
        #   "FOO" => Secret.new(name: "creds").key("bar")
        #     =>  { name: "FOO", valueFrom: { secretKeyRef: { name: "creds", key: "bar" } } }
        #
        # ExternalSecret::KeyRef values reference a key the ExternalSecret
        # already materialises (declared via keys: at construction, or by a
        # .template call elsewhere) -- unlike .template, .key registers
        # NOTHING on the ExternalSecret. Reference a key that never lands in
        # the target Secret and the pod sits in CreateContainerConfigError.
        #   "FOO" => ExternalSecret::Creds.key("bar")
        #     =>  { name: "FOO", valueFrom: { secretKeyRef: { name: "creds", key: "bar" } } }
        #
        def self.process(env)
          return env if env.is_a?(Array)
          return [] if env.nil?

          env.map do |key, value|
            key = key.to_s

            case value
            when ESO::ExternalSecret::TemplateRef
              value.secret.register_template!(key, value.template_value)
              { name: key, valueFrom: { secretKeyRef: { name: value.secret.secret_name, key: key } } }
            when ESO::ExternalSecret::KeyRef, Kube::Cluster::Standard::Secret::KeyRef
              { name: key, valueFrom: { secretKeyRef: { name: value.secret.secret_name, key: value.key_name } } }
            else
              { name: key, value: value.to_s }
            end
          end
        end
      end
    end
  end
end

__END__

describe "EnvProcessing" do
  it "maps a Secret::KeyRef to a secretKeyRef env var" do
    secret = Kube::Cluster::Standard::Secret.new(name: "passbolt-db-creds")

    Kube::Cluster::Standard::EnvProcessing
      .process("DB_PASSWORD" => secret.key("password"))
      .should == [
        { name: "DB_PASSWORD", valueFrom: { secretKeyRef: { name: "passbolt-db-creds", key: "password" } } }
      ]
  end

  it "maps an ExternalSecret::KeyRef to a secretKeyRef env var without registering anything" do
    secret = Kube::Cluster::Standard::ESO::ExternalSecret.new(
      name: "svix-jwt", store: "passbolt", remote_key: "svix-jwt",
      keys: { "SVIX_JWT_SECRET" => "SVIX_JWT_SECRET" }
    )

    Kube::Cluster::Standard::EnvProcessing
      .process("SVIX_JWT_SECRET" => secret.key("SVIX_JWT_SECRET"))
      .should == [
        { name: "SVIX_JWT_SECRET", valueFrom: { secretKeyRef: { name: "svix-jwt", key: "SVIX_JWT_SECRET" } } }
      ]

    # Unlike .template, .key must not touch the ExternalSecret's spec.
    secret.to_h.dig(:spec, :target, :template).should.be.nil
    secret.to_h.dig(:spec, :data).length.should == 1
  end

  it "still maps plain string values to value env vars" do
    Kube::Cluster::Standard::EnvProcessing
      .process("FOO" => "bar")
      .should == [{ name: "FOO", value: "bar" }]
  end
end
