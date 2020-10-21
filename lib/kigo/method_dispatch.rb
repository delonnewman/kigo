module Kigo
  class MethodDispatch
    attr_reader :method

    def self.parse(string, env)
      subject, method = string.split(Reader::PERIOD)
      new(subject.to_sym, method.to_sym, env)
    end

    def initialize(subject, method, env)
      @subject = subject
      @method  = method
      @env     = env
    end

    def to_s
      "#{@subject}.#{@method}"
    end

    def subject
      @subject_value ||= @env.lookup_value!(@subject)
    end

    def call(*args)
      subject.send(method, *args)
    end
  end
end