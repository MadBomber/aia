# lib/aia/tools/editor.rb
# This is the default editor setup in the
# system environment variable EDITOR


class AIA::Editor < AIA::Tools

  meta(
    name:     'editor',
    role:     :editor,
    desc:     "Your default system $EDITOR",
    url:      "unknown",
    install:  "should already be installed",
  )

  DEFAULT_PARAMETERS = ""
  
  attr_accessor :command


  def initialize(file: "")    
    @file     = file

    discover_editor

    build_command
  end


  def discover_editor
    editor = ENV['EDITOR']  # This might be nil

    if editor.nil?
      @name         = "echo"
      @description  = "You have no default editor"
      @install      = "Set your system environment variable EDITOR"
    else
      @name = editor
    end    
  end


  def build_command
    @command = "#{meta.name} #{DEFAULT_PARAMETERS} #{@file}"
  end

  
  def run
    `#{command}`
  end
end

