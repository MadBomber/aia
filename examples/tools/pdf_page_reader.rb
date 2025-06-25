# examples/tools/pdf_page_reader.rb
# See: https://max.engineer/giant-pdf-llm

require "ruby_llm/tool"
require 'pdf-reader'


class PdfPageReader < RubyLLM::Tool
  # TODO: make the path to the pdf document a parameter
  DOC = PDF::Reader.new('docs/big-doc.pdf')

  description 'Read the text of any set of pages from a PDF document.'
  param :page_numbers,
    desc: 'Comma-separated page numbers (first page: 1). (e.g. "12, 14, 15")'

  def execute(page_numbers:)
    puts "\n-- Reading pages: #{page_numbers}\n\n"
    page_numbers = page_numbers.split(',').map { _1.strip.to_i }
    pages = page_numbers.map { [_1, DOC.pages[_1.to_i - 1]] }
    {
      pages: pages.map { |num, p|
        # There are lines drawn with dots in my doc.
        # So I squeeze them to save tokens.
        { page: num, text: p&.text&.squeeze('.') }
      }
    }
  rescue => e
    { error: e.message }
  end
end
