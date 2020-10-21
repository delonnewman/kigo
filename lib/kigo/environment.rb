module Kigo
  class Environment
    attr_reader :variables, :parent

    def self.top_level
      @top_level ||= new(RubyEnvironment.instance)
    end

    def initialize(parent = nil)
      @variables = {}
      @parent = parent
    end

    def branch
      self.class.new(self)
    end

    def value(symbol)
      @variables[symbol]
    end

    def define(symbol, value = nil)
      @variables[symbol] = value

      symbol
    end

    def lookup(symbol)
      return self if  @variables.key?(symbol)
      return nil  if !@variables.key?(symbol) && @parent.nil?

      @parent.lookup(symbol)
    end

    def lookup!(symbol)
      scope = lookup(symbol)
      raise RuntimeError, "Undefined variable: #{symbol}" if scope.nil?

      scope
    end

    def lookup_value!(symbol)
      return self if symbol == :'*env*'

      lookup!(symbol).value(symbol)
    end

    def to_s
      "#<Environment variables: #{@variables.keys.join(', ')} parent: #{@parent.inspect}>"
    end
    alias inspect to_s
  end

  class RubyEnvironment < Environment
    include Singleton

    def lookup_value!(symbol)
      string = symbol.to_s
      if constant?(string)
        string.split('::').reduce(Object) do |const, name|
          const.const_get(name.to_sym)
        end
      #elsif (method = Kigo.current_module.method(symbol))
      #  method
      else
        Kigo::Core.method(symbol)
      end
    end

    def lookup!(symbol)
      lookup_value!(symbol)
      self
    end

    def value(symbol)
      lookup_value!(symbol)
    end

    def lookup(symbol)
      begin
        lookup_value!(symbol)
        self
      rescue NameError => e
        nil
      end
    end

    def define(symbol, value)
      # TODO: we may want to permit this
      raise "Cannot define new variables in Ruby Environment"
    end

    private

    def constant?(str)
      str[0].upcase == str[0]
    end
  end
end