# frozen_string_literal: true

module Kube
  module Cluster
    class ResourceSelector < Array
      def +(other)
        self.class.new(super)
      end

      def to_s
        join(".")
      end

      def to_regex
        Regexp.new(map { |s| Regexp.escape(s) }.join('.*\.'))
      end
    end
  end
end
