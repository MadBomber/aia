# test/aia/tools/vim_test.rb

require_relative '../../test_helper'
require_relative '../../../lib/aia/tools/vim'


class TestVim < Minitest::Test
  def setup
    @vim = AIA::Vim.new(file: 'test.txt')
  end


  ############################################
  def test_initialize
    assert_equal :editor, @vim.role
    assert_equal "Vi IMproved (VIM)",   @vim.description
    assert_equal "https://www.vim.org", @vim.url
    assert_equal "brew install vim",    @vim.install
    assert_equal 'test.txt',            @vim.instance_variable_get(:@file)
  end


  def test_build_command
    @vim.build_command
    assert_equal "vim   test.txt", @vim.command
  end


  def test_run
    # This will test if command is invoked correctly, mocking system call
    system_mock = Minitest::Mock.new
    system_mock.expect(:call, true, [@vim.command]) # Expecting a system call with the command
    @vim.stub :system, system_mock do
      @vim.run
    end
    system_mock.verify
  end
end



