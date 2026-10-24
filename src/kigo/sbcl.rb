# frozen_string_literal: true

require 'securerandom'

module Kigo
  class SBCL
    def initialize(path)
      @path = path
      @io   = nil
    end

    def start
      @io ||= IO.popen([@path, '--noinform', '--disable-debugger'], 'r+')
      at_exit { @io.close unless @io.closed? }
      self
    end

    def stop
      return unless @io

      @io.puts '(sb-ext:exit)'
      @io.close
      @io = nil

      self
    end

    def kill
      return unless @io

      Process.kill('TERM', @io.pid)
      @io = nil

      self
    end

    SENTINEL = "__KIGO_DONE_#{SecureRandom.base64}__".freeze

    def eval_string(code)
      raise "service has not been initialized call 'start' method" unless @io

      @io.puts code
      @io.puts %((format t "~%#{SENTINEL}~%"))
      @io.flush

      lines = []
      while (line = @io.gets)
        line.chomp!
        line.sub!(/^\*\s/, '')
        break if line == SENTINEL
        next  if line.empty? || line =~ /\A\s+\z/ || line == 'NIL'

        lines << line
      end
      lines
    end
  end
end

__END__

sbcl = Kigo::SBCL.new('/opt/homebrew/bin/sbcl').start
sbcl.eval_string('(+ 12 34)')
sbcl.eval_string('(list 1 2 3)')
sbcl.eval_string('(defun ident (x) x) (ident 56)')
sbcl.stop
