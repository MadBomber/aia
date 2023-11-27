# lib/aia/external/tool.rb

class AIA::External::Tool
  @@subclasses = []

  # This method is called whenever a subclass is created
  def self.inherited(subclass)
    @@subclasses << subclass
  end


  attr_reader :name, :description, :url

  def initialize
    @role     = :role
    @name     = self.class.name.split('::').last.downcase
    @desc     = "description"
    @url      = "URL"
    @install  = "brew install #{name}"
  end


  def self.tools
    @@subclasses.map(&:name)
  end


  def installed?
    path = `which #{name}`.chomp
    !path.empty? && File.executable?(path)
  end


  def help    = `#{name} --help`
  def version = `#{name} --version`


  ###################################################
  class << self
    def verify_tools(tools)
      missing_tools = tools.reject(&:installed?)
      unless missing_tools.empty?
        puts format_missing_tools_response(missing_tools)
      end
    end


    def format_missing_tools_response(missing_tools)
      response = <<~EOS

        WARNING: AIA makes use of external CLI tools that are missing.

        Please install the following tools:

      EOS

      missing_tools.each do |tool|
        response << "  #{tool.name}: install from #{tool.url}\n"
      end

      response
    end
  end
end


Pathname.new(__dir__)
  .glob('*.rb')
  .reject{|f| f.basename.to_s.end_with?('tool.rb') }
  .each do |tool|
    require_relative tool.basename.to_s 
  end

