# frozen_string_literal: true

module Kube
  module Cluster
    module ScriptCommands
      def BashScript(*strings)   = ['bash', '-exc', *strings]
      def PythonScript(*strings) = ['python3', '-c', *strings]
      def RubyScript(*strings)   = ['ruby', '-e', *strings]
      def ShScript(*strings)     = ['sh', '-exc', *strings]
    end

    include ScriptCommands
    module_function :BashScript, :PythonScript, :RubyScript, :ShScript
  end
end

# Make script helpers available inside instance_exec blocks on Hashes.
# Without this, Hash#method_missing (autovivification) silently swallows
# calls like ShScript(...) and returns {} instead of an array.
Hash.include(Kube::Cluster::ScriptCommands)
