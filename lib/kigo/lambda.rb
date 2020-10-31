 module Kigo
  class Lambda
    attr_reader :arity, :arglist, :code, :env

    def initialize(args, code, env)
      @arglist = args
      @code    = code
      @env     = env.branch
      parse_arguments!
    end

    alias body code

    def to_s
      Cons.new(:lambda, Cons.new(@arglist, Cons.new(@code, Cons.empty))).to_s
    end
    alias inspect to_s
    
    def call(*args)
      @args.each_with_index do |arg, i|
        if arity < 0 && arity.abs == i + 1
          env.define(arg, Cons[*args[i, args.length]])
          break
        else
          env.define(arg, args[i])
        end
      end

      value = nil
      @code.each do |form|
        value = Kigo.eval(form, env)
      end
      value
    end

    def to_proc
      l = self
      lambda do |*args|
        if l.arity > 0 && args.size != l.arity
          raise ArgumentError, "wrong number of arguments expected #{l.arity}, got #{args.size}"
        end
        l.call(*args)
      end
    end

    private

    def parse_arguments!
      @arity = 0
      @args = @arglist.map do |arg|
        raise SyntaxError, "unexpected #{arg.class}, expecting symbol" unless Symbol === arg
        @arity += 1
        if arg.to_s.start_with?('*')
          @arity *= -1
          arg[1, arg.length - 1].to_sym
        else
          arg
        end
      end
    end
  end
 end