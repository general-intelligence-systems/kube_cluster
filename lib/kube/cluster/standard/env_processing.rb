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
        def self.process(env)
          return env if env.is_a?(Array)
          return [] if env.nil?

          env.map do |key, value|
            key = key.to_s

            case value
            when ESO::ExternalSecret::TemplateRef
              value.secret.register_template!(key, value.template_value)
              { name: key, valueFrom: { secretKeyRef: { name: value.secret.secret_name, key: key } } }
            when Kube::Cluster::Standard::Secret::KeyRef
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

  it "still maps plain string values to value env vars" do
    Kube::Cluster::Standard::EnvProcessing
      .process("FOO" => "bar")
      .should == [{ name: "FOO", value: "bar" }]
  end
end
