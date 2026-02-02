module Kigo
  class Assignment
    attr_reader :subject, :value

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
