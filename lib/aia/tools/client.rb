# lib/aia/tools/client.rb

require "ai_client"


class AIA::Client
  def initialize(model = AIA.config.model, **options)
    AiClient.new(model, **options)
  end
end
