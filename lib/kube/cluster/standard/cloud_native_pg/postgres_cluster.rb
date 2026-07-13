# frozen_string_literal: true

require "bundler/setup"
require "kube/cluster"
require "kube/cluster/standard/cloud_native_pg/cluster"

module Kube
  module Cluster
    module Standard
      module CloudNativePg
        # The standard single-node PostgreSQL cluster: custom image, HA
        # replication slots, logical WAL, and barman-cloud WAL archiving.
        # Deployment-specific additions (managed roles, extra spec) come via the
        # block; databases are separate Database CRs.
        class PostgresCluster < Cluster
          def initialize(name: "postgres", namespace: nil, &block)
            super(name: name, namespace: namespace) {
              spec.affinity = { podAntiAffinityType: "preferred" }
              spec.bootstrap = {
                initdb: {
                  database: "app",
                  encoding: "UTF8",
                  localeCType: "C",
                  localeCollate: "C",
                  owner: "app",
                },
              }
              spec.enablePDB = true
              spec.enableSuperuserAccess = false
              spec.failoverDelay = 0
              spec.imageName = "ghcr.io/general-intelligence-systems/postgresql:17-custom"
              spec.imagePullPolicy = "Always"
              spec.instances = 1
              spec.plugins = [{
                name: "barman-cloud.cloudnative-pg.io",
                isWALArchiver: true,
                parameters: { barmanObjectName: "cnpg-backups" },
              }]
              spec.logLevel = "info"
              spec.maxSyncReplicas = 0
              spec.minSyncReplicas = 0
              spec.monitoring = {
                disableDefaultQueries: false,
                enablePodMonitor: false,
              }
              spec.postgresGID = 26
              spec.postgresUID = 26
              spec.postgresql = {
                parameters: {
                  archive_mode: "on",
                  archive_timeout: "5min",
                  dynamic_shared_memory_type: "posix",
                  full_page_writes: "on",
                  log_destination: "csvlog",
                  log_directory: "/controller/log",
                  log_filename: "postgres",
                  log_rotation_age: "0",
                  log_rotation_size: "0",
                  log_truncate_on_rotation: "false",
                  logging_collector: "on",
                  max_parallel_workers: "32",
                  max_replication_slots: "32",
                  max_worker_processes: "32",
                  shared_memory_type: "mmap",
                  shared_preload_libraries: "",
                  ssl_max_protocol_version: "TLSv1.3",
                  ssl_min_protocol_version: "TLSv1.3",
                  wal_keep_size: "512MB",
                  wal_level: "logical",
                  wal_log_hints: "on",
                  wal_receiver_timeout: "5s",
                  wal_sender_timeout: "5s",
                },
                syncReplicaElectionConstraint: {
                  enabled: false,
                },
              }
              spec.primaryUpdateMethod = "restart"
              spec.primaryUpdateStrategy = "unsupervised"
              spec.probes = {
                liveness: {
                  isolationCheck: {
                    connectionTimeout: 1000,
                    enabled: true,
                    requestTimeout: 1000,
                  },
                },
              }
              spec.replicationSlots = {
                highAvailability: {
                  enabled: true,
                  slotPrefix: "_cnpg_",
                },
                synchronizeReplicas: {
                  enabled: true,
                },
                updateInterval: 30,
              }
              spec.resources = {}
              spec.smartShutdownTimeout = 180
              spec.startDelay = 3600
              spec.stopDelay = 1800
              spec.storage = {
                resizeInUseVolumes: true,
                size: "5Gi",
              }
              spec.switchoverDelay = 3600

              instance_exec(&block) if block
            }
          end
        end
      end
    end
  end
end

__END__

describe "CloudNativePg::PostgresCluster" do
  it "initializes without error" do
    Kube::Cluster::Standard::CloudNativePg::PostgresCluster
      .new(namespace: "cloudnative-pg")
      .to_yaml
      .is_a?(String)
      .should == true
  end
end
