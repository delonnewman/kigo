# frozen_string_literal: true

require 'pathname'

module Kigo
  class LispProgram
    def initialize(code)
      @code = code
      freeze
    end

    def to_s
      <<~LISP
        (load "#{Kigo.kernel}")

        (defun main ()
          #{@code}
          (sb-ext:exit :code 0))
      LISP
    end
  end
end
