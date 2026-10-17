# frozen_string_literal: true

source "https://rubygems.org"

gem "activesupport", "~> 8.0"
gem "kube_kubectl", "~> 2.0"
gem "kube_schema", "~> 2.0"

gem "lefthook", "~> 2.1"
gem "rake", "~> 13.0"
gem "scampi", "~> 1.0"
gem "rubocop"
gem "decode"

group :release do
	gem "gem_kit-release", "~> 0.3"
end

group :maintenance, optional: true do
	gem "utopia-project"
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
end
