# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        class ExternalSecret < Kube::Cluster["ExternalSecret"]

          DB_HOST = "postgres-rw.cloudnative-pg.svc.cluster.local"

          def initialize(name:, env_prefix: "DB", db_host: DB_HOST, &block)
            super() {
              metadata.name = "#{name}-db"
              spec.refreshInterval = "1h"
              spec.secretStoreRef = { kind: "ClusterSecretStore", name: "cnpg-credentials" }
              spec.target = {
                name: "#{name}-db",
                creationPolicy: "Owner",
                deletionPolicy: "Retain",
                template: {
                  data: {
                    "#{env_prefix}_URL"      => "jdbc:postgresql://#{db_host}:5432/#{name}",
                    "#{env_prefix}_USER"     => "{{ .username }}",
                    "#{env_prefix}_PASSWORD" => "{{ .password }}",
                  },
                },
              }
              spec.data = [
                { secretKey: "username", remoteRef: { key: "postgres-app", property: "username" } },
                { secretKey: "password", remoteRef: { key: "postgres-app", property: "password" } },
              ]

              instance_exec(&block) if block_given?
            }
          end
        end
      end
    end
  end
end

test do
  describe "CloudNativePg::ExternalSecret" do
    it "initializes without error" do
      Kube::Cluster::Standard::CloudNativePg::ExternalSecret
        .new(
          name: "my-external-secret"
        )
        .to_yaml
        .is_a?(String)
        .should == true
    end
  end
end
