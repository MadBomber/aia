require 'ruby_llm'
require_relative 'modalities'

RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
end

C = RubyLLM::Chat.new
M = C.model.modalities

__END__

# I = ["text", "image", "pdf", "audio", "file"]
# O = ["text", "embeddings", "audio", "image", "moderation"]

# I.each do |i|
#   puts '#'
#   O.each do |o|
#     puts <<~HEREDOC
#       def #{i}_to_#{o}? = input.include?('#{i}') && output.include?('#{o}')
#     HEREDOC
#   end
# end



#
def text_to_text? = input.include?('text') && output.include?('text')
def text_to_embeddings? = input.include?('text') && output.include?('embeddings')
def text_to_audio? = input.include?('text') && output.include?('audio')
def text_to_image? = input.include?('text') && output.include?('image')
def text_to_moderation? = input.include?('text') && output.include?('moderation')
#
def image_to_text? = input.include?('image') && output.include?('text')
def image_to_embeddings? = input.include?('image') && output.include?('embeddings')
def image_to_audio? = input.include?('image') && output.include?('audio')
def image_to_image? = input.include?('image') && output.include?('image')
def image_to_moderation? = input.include?('image') && output.include?('moderation')
#
def pdf_to_text? = input.include?('pdf') && output.include?('text')
def pdf_to_embeddings? = input.include?('pdf') && output.include?('embeddings')
def pdf_to_audio? = input.include?('pdf') && output.include?('audio')
def pdf_to_image? = input.include?('pdf') && output.include?('image')
def pdf_to_moderation? = input.include?('pdf') && output.include?('moderation')
#
def audio_to_text? = input.include?('audio') && output.include?('text')
def audio_to_embeddings? = input.include?('audio') && output.include?('embeddings')
def audio_to_audio? = input.include?('audio') && output.include?('audio')
def audio_to_image? = input.include?('audio') && output.include?('image')
def audio_to_moderation? = input.include?('audio') && output.include?('moderation')
#
def file_to_text? = input.include?('file') && output.include?('text')
def file_to_embeddings? = input.include?('file') && output.include?('embeddings')
def file_to_audio? = input.include?('file') && output.include?('audio')
def file_to_image? = input.include?('file') && output.include?('image')
def file_to_moderation? = input.include?('file') && output.include?('moderation')
