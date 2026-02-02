module Kigo
  class Assignment
    attr_reader :subject, :value

    def self.from_data(form)
      raise SyntaxError, "invalid form, expected: (set! SUBJECT VALUE)" unless form.length == 3

      new(form[1], form[2])
    end

    def initialize(subject, value)
      @subject = subject
      @value   = value
    end

    def method_assignment?
      @subject.is_a?(Cons)
    end

    def member_assignment?
      @subject.is_a?(Array)
    end
  end
end
