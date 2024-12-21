# lib/aia/configuration_validator.rb

class AIA::ConfigurationValidator
  def initialize(config)
    @config = config
  end

  def valid?
    validate_model_configuration &&
    validate_file_paths &&
    validate_option_combinations
  end

  private

  def validate_model_configuration
    !AIA.config.model.nil? && !AIA.config.model.empty?
  end

  def validate_file_paths
    AIA.config.prompts_dir.exist? &&
    AIA.config.roles_dir.exist?
  end

  def validate_option_combinations
    validate_chat_options &&
    validate_pipeline_options
  end

  def validate_chat_options
    return true unless AIA.config.chat?
    
    AIA.config.next.empty? &&
    AIA.config.pipeline.empty? &&
    STDOUT == AIA.config.out_file
  end

  def validate_pipeline_options
    return true if AIA.config.next.empty?
    AIA.config.pipeline.empty?
  end
end

