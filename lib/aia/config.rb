# lib/aia/config.rb

require 'erb'
require 'tomlrb'

MY_NAME         = "aia"
HOME            = Pathname.new(ENV['HOME'])

PROMPTS_DIR     = Pathname.new(ENV['PROMPTS_DIR'] || (HOME + ".prompts_dir"))
OUTPUT          = Pathname.pwd + "temp.md"
PROMPT_LOG      = PROMPTS_DIR  + "_prompts.log"



=begin
  What are we configuring and why?

  This entire idea of external tools and
  their configuration may be a
  stupid one.  If the only reason is
  to provide capability for the 
  search_proc option in the
  prompt_manager then the example
  rgfzf bash file is sufficient.
  No need to complicate things here./

  The only two external tools used
  by aia directly are the editor
  and the resolver (mods)

=end


class AIA::Config
  FILENAME  = "aia.toml"
  LOOK_HERE = [
    Pathname.pwd,
    HOME
  ]

  def initialize(path_to_config_file=nil)
    load_config(path_to_config_file)
  end

  # The config file is TOML formated argumented with
  # ERB.

  def load_config(path)
    @config     = Hash.new
    config_path = path.nil? ? find_config : path

    if config_path.nil?
      unless quite?
        STDERR.puts <<~WARNING

          Warning:  No configuration file provided - using the default.
                    Use the --dump-config to see the default config being used.
                    The name of the default config file is fixed as "aia.toml" It
                    should be placed in your project's directory or in your HOME
                    directory.

        WARNING
      end
      config_path = Pathname.new(__dir__) + FILENAME
    end
        
    erb_template  = config_path.read
    erb           = ERB.new(erb_template)
    toml_content  = erb.result(binding)
    @config       = Tomlrb.parse(toml_content) 
  end


  def find_config
    config_path = nil

    LOOK_HERE.each do |path|
      fonfig_path = path + FILENAME
      if fonfig_path.exist?
        the_path = config_path
        break
      end
    end

    config_path
  end

  def backend = @config['backend']
  def editor  = @config['editor']
  def search  = @config['search']

  def backend_options = options(backend)
  def editor_options  = options(editor)
  def search_options  = options(search)


  def options(tool_name)
    a_hash = @config[tool_name]

    opts = ""

    a_hash.each_pair do |k, v|
      opts += 1 == k.length ? " -" : " --"
      opts += "#{k} "
      opts += v.is_a?(TrueClass) ? "" : v
    end

    opts
  end


  ######################################################
  class << self
    def dump_default
      default_config_file = Pathname.new(__dir__) + FILENAME

      puts
      puts default_config_file.read
      puts

      exit
    end
  end
end



__END__


erb_template  = File.read("config.toml.erb")
erb           = ERB.new(erb_template)
toml_content  = erb.result(binding)
