# frozen_string_literal: true

# lib/aia/robot_sync.rb
#
# The robot (or crew) is built once from the configuration at startup, but a
# prompt's front matter (model:, temperature:, top_p:, config: llm: ...) and
# chat directives (/temperature, /top_p, /config llm.*) change the
# configuration later. RobotSync runs before each prompt and chat turn and
# brings the running client in line with the configuration:
#
#   * the model list changed  -> rebuild the client (as /model does), carrying
#                                the conversation over per model_switch_history
#   * only LLM settings changed -> retune every robot in place, keeping history
#
# A client replaced elsewhere (e.g. by /model) becomes the new baseline.

module AIA
  class RobotSync
    # @param config [AIA::Config] the live configuration
    # @param client [RobotLab::Robot, RobotLab::Network, nil] the client as built
    # @param factory [#rebuild, #llm_params] builds and parameterizes clients
    def initialize(config, client, factory: RobotFactory)
      @config  = config
      @factory = factory
      record(client)
    end

    # @param client [RobotLab::Robot, RobotLab::Network] the current client
    # @return [RobotLab::Robot, RobotLab::Network] the client to use from now on
    def call(client)
      return record(client) unless client.equal?(@client)

      if model_signature != @models
        rebuild
      elsif @factory.llm_params(@config) != @params
        retune(client)
      else
        client
      end
    end

    # The models (name, role) the client should be running.
    def model_signature
      Array(@config.models).map { [it.name, it.role] }
    end

    # Robot#update keywords for +params+ (from RobotFactory.llm_params).
    # top_p and the penalties go to the provider as request options; they are
    # always sent (possibly empty) so a value that was cleared is dropped.
    def self.update_options(params)
      options = {}
      options[:temperature]       = params[:temperature] if params.key?(:temperature)
      options[:max_output_tokens] = params[:max_tokens]  if params.key?(:max_tokens)
      options[:provider_options]  = params.slice(:top_p, :frequency_penalty, :presence_penalty)
      options
    end

    private

    def rebuild
      client = @factory.rebuild(@config, history_mode: HistoryTransfer.mode_for(@config))
      AIA.client = client
      record(client)
    end

    def retune(client)
      options = self.class.update_options(@factory.llm_params(@config))
      HistoryTransfer.recipients(client).each { |robot| robot.update(**options) if robot.respond_to?(:update) }
      record(client)
    end

    def record(client)
      @client = client
      @models = model_signature
      @params = @factory.llm_params(@config)
      client
    end
  end
end
