# lib/string_wrap.rb

require 'io/console'

# This is a monkey patch to the String class which is
# okay in this context since this program is a
# stand-alone terminal utility.  Otherwise we would
# use a refinement or a namespace to keep this from
# impact other code.

class String
  def wrap(line_width: nil, indent: 0)
    # If line_width is not given, try to detect the terminal width
    line_width ||= IO.console ? IO.console.winsize[1] : 80

    # Prepare the prefix based on the type of the indent parameter
    prefix = indent.is_a?(String) ? indent : ' ' * indent.to_i

    # Split the string into paragraphs first, preserve paragraph breaks
    paragraphs = self.split(/\n{2,}/)

    # Create an empty array that will hold all wrapped paragraphs
    wrapped_paragraphs = []

    # Process each paragraph separately
    paragraphs.each do |paragraph|
      wrapped_lines = [] # Create an empty array for wrapped lines of the current paragraph
      
      # Split the paragraph into lines first, in case there are single newlines
      lines = paragraph.split(/(?<=\n)/)

      # Process each line separately to maintain single newlines
      lines.each do |line|
        words         = line.split
        current_line  = ""

        words.each do |word|
          if word.include?("\n") && !word.strip.empty?
            # If the word contains a newline, split and process as separate lines
            parts = word.split(/(?<=\n)/)

            parts.each_with_index do |part, index|
              if part == "\n"
                wrapped_lines << prefix + current_line
                current_line = ""
              else
                current_line << " " unless current_line.empty? or index == 0
                current_line << part.strip
              end
            end

          elsif current_line.length + word.length + 1 > line_width - prefix.length
            wrapped_lines << prefix + current_line.rstrip
            current_line  = word

          else
            current_line << " " unless current_line.empty?
            current_line << word
          end
        end

        # Don't forget to add the last line unless it's empty
        wrapped_lines << prefix + current_line unless current_line.empty?
      end

      # Preserve the paragraph structure by joining the wrapped lines and append to the wrapped_paragraphs array
      wrapped_paragraphs << wrapped_lines.join("\n")
    end

    # Join wrapped paragraphs with double newlines into a single string
    wrapped_paragraphs.join("\n\n")
  end
end

__END__

# TODO: turn these into unit tests.

# Usage example with default line length
puts <<~EOS.wrap(indent: ' Given -=> ') # Using a string of two spaces as indent
Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus. Cras mattis consectetur purus sit amet fermentum.

Donec sed odio dui. Cras justo odio, dapibus ac facilisis in, egestas eget quam. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus.

This is a sample text with a newline
character that needs to be wrapped according to the width of the terminal.
EOS

puts "=" * 64

# Usage example
puts <<~EOS.wrap(line_width: 64, indent: ' -=> ') # Using a string of two spaces as indent
Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus. Cras mattis consectetur purus sit amet fermentum.

Donec sed odio dui. Cras justo odio, dapibus ac facilisis in, egestas eget quam. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus.

This is a sample text with a newline
character that needs to be wrapped according to the width of the terminal.
EOS

puts "=" * 64

puts <<~EOS.wrap(line_width: 64, indent: 8)
Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus. Cras mattis consectetur purus sit amet fermentum.

Donec sed odio dui. Cras justo odio, dapibus ac facilisis in, egestas eget quam. Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia odio sem nec elit. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Fusce dapibus, tellus ac cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit amet risus.

This is a sample text with a newline
character that needs to be wrapped according to the width of the terminal.
EOS

