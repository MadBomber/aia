# lib/aia/logging.rb

module AIA::Logging
  def log_result
    return if log.nil?
    
    f = File.open(log, "ab")

    f.write <<~EOS
      =======================================
      == #{Time.now}
      == #{@prompt.path}

      PROMPT:
      #{@prompt}

      RESULT:
      #{@result}

    EOS
  end
end
