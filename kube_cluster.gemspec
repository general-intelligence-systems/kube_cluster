# frozen_string_literal: true

require_relative "lib/kube/cluster/version"

Gem::Specification.new do |spec|
  spec.name = "kube_cluster"
  spec.version = Kube::Cluster::VERSION
  spec.authors = ["Nathan K"]
  spec.email = ["nathankidd@hey.com"]

  spec.summary = "Ruby-native Kubernetes"

  spec.description = <<~DESC
    OOP abstraction that allows you to deploy and manage kubernetes resources using Ruby.
  DESC

  spec.homepage = "https://github.com/general-intelligence-systems/kube_cluster"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["documentation_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"

  spec.add_dependency "kube_schema", "~> 1.3.0"
  spec.add_dependency "kube_kit", "> 0"
  spec.add_dependency "kube_kubectl", "~> 2.0.0"
end
