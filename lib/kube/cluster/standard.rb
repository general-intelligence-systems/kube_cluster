# frozen_string_literal: true
#
# Opt-in loader for the whole Standard tree.
#
# `require "kube/cluster"` deliberately does NOT auto-load the Standard classes
# (so resolve overrides can be configured before they bind their superclasses).
# Requiring this file pulls in every Standard class at once — the convenient
# "give me all of them" entry point for projects that use most of the tree.
require "kube/cluster"

Dir.glob("#{__dir__}/standard/**/*.rb").sort.each do |path|
  require path
end
