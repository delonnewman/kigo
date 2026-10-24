# frozen_string_literal: true

require 'pathname'

module Kigo
  class LispProgram
    def initialize(code)
      @code = code
      @kernel = Pathname.new(__dir__).join('../../lib').join('kernel.lisp')
      freeze
    end

    def to_s
      <<~LISP
      (load "#{@kernel}")

      (defun main ()
         #{@code}
         (sb-ext:exit :code 0))
      LISP
    end
  end
end
