# frozen_string_literal: true

# lib/aia/network_memory_manager.rb
#
# Manages shared memory initialization and subscriptions for
# multi-robot networks. Extracted from RobotFactory.

module AIA
  class NetworkMemoryManager
    class << self
      # Initialize shared memory for a network with session context.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      # @return [RobotLab::Network]
      def initialize_memory(network, config)
        return network unless network.respond_to?(:memory)

        data = network.memory.data
        data.session_id  = SecureRandom.hex(8)
        data.model_count = config.models.size
        data.model_names = config.models.map(&:name)
        data.mode        = config.flags.consensus ? :consensus : :parallel
        data.turn_count  = 0

        network
      end

      # Set up memory subscriptions for debug logging and completion tracking.
      #
      # @param network [RobotLab::Network]
      # @param config [AIA::Config]
      def setup_subscriptions(network, config)
        return unless network.respond_to?(:memory)

        memory = network.memory

        if config.flags.debug
          memory.subscribe_pattern("result_*") do |change|
            AIA::LoggerManager.aia_logger.debug(
              "Memory: #{change.key} by #{change.writer} at #{change.timestamp}"
            )
          end
        end

        memory.set(:completed_count, 0)
        memory.subscribe_pattern("result_*") do |change|
          next unless change.created?
          count = memory.get(:completed_count) || 0
          memory.set(:completed_count, count + 1)
        end
      end
    end
  end
end
