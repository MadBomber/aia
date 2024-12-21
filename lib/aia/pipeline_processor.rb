# lib/aia/pipeline_processor.rb


class AIA::PipelineProcessor
  def initialize(result:)
    @result = result
  end

  def process
    return if AIA.config.pipeline.empty?
    
    with_temp_file(@result) do |temp_path|
      update_config(temp_path)
      process_next_prompt
    end
  end

  private

  def update_config(temp_path)
    AIA.config.directives = []
    AIA.config.model = ""
    AIA.config.arguments = [AIA.config.pipeline.shift, temp_path]
    AIA.config.next = ""
    AIA.config.files = [temp_path]
  end
end

