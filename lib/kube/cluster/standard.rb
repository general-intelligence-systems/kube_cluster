# frozen_string_literal: true
#
# Opt-in loader for the whole Standard tree.
#
# `require "kube/cluster"` does not auto-load Standard classes.
# This pulls in every Standard class at once: give-me-all-of-them.
require "kube/cluster"

Dir.glob("#{__dir__}/standard/**/*.rb").sort.each do |path|
  require path
end
