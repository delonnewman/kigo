module Kigo
  class Var
    attr_reader :value

    def initialize(value = nil, dynamic: false)
      @value   = value
      @dynamic = dynamic
    end

    def dynamic?
      @dynamic
    end

    def set!(value)
      if @value.nil? or dynamic?
        @value = value
      end
      self
    end

    def to_s
      "#<Var #{value.inspect}>"
    end
    alias inspect to_s
  end
end