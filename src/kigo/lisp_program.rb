# frozen_string_literal: true

module Kigo
  class LispProgram
    def initialize(code)
      @code = code
      freeze
    end

    def to_s
      <<~LISP
      "(defun main ()
         #{@code}
         (sb-ext:exit :code 0))"
      LISP
    end
  end
end
