# lib/aia/pipeline_processor.rb


class AIA::PipelineProcessor
  def initialize(result:, config:)
    @result = result
    @config = config
  end

  def process
    return if @config.pipeline.empty?
    
    with_temp_file(@result) do |temp_path|
      update_config(temp_path)
      process_next_prompt
    end
  end
end

