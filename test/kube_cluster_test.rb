# frozen_string_literal: true

require "test_helper"

class KubeClusterTest < Minitest::Test
  def test_version
    refute_nil Kube::Cluster::VERSION
  end
end
