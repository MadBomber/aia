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
end

