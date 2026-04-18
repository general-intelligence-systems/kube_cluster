# frozen_string_literal: true

require "kube/cli"
require "kube/cluster"

Kube::CLI.register "cluster", ->(argv) {
  subcommand = argv.shift

  case subcommand
  when "connect", nil
    kubeconfig = ENV["KUBECONFIG"]

    # Parse --kubeconfig flag
    if (idx = argv.index("--kubeconfig"))
      kubeconfig = argv[idx + 1]
      argv.slice!(idx, 2)
    elsif (flag = argv.find { |a| a.start_with?("--kubeconfig=") })
      kubeconfig = flag.split("=", 2).last
      argv.delete(flag)
    end

    if kubeconfig.nil?
      $stderr.puts "kube cluster connect: missing --kubeconfig or KUBECONFIG env var"
      exit 1
    end

    instance = Kube::Cluster.connect(kubeconfig: kubeconfig)
    puts instance.inspect

  when "help", "--help", "-h"
    puts "Usage: kube cluster <subcommand> [options]"
    puts
    puts "Subcommands:"
    puts "  connect    Connect to a cluster (--kubeconfig=PATH or KUBECONFIG env)"
    puts

  else
    $stderr.puts "kube cluster: unknown subcommand '#{subcommand}'"
    exit 1
  end
}, description: "Manage cluster connections"
