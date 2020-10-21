# frozen_string_literal: true
require 'forwardable'

module Kigo
  class Evaluator
    attr_reader :env

    def initialize(env = Environment.top_level)
      @env = env
    end

    def evaluate(form)
      case form
      when String, Numeric, true, false, nil
        form
      when Keyword
        form.symbol
      when Array
        eval_array(form, env)
      when Set
        eval_set(form, env)
      when Hash
        eval_hash(form, env)
      when Symbol
        eval_symbol(form, env)
      when Cons
        return Cons.empty if form.empty?
        if (evaluator = Syntax.forms[form.first])
          evaluator.parse(form).evaluate(env)
        else
          eval_application(form, env)
        end
      else
        raise RuntimeError, "Invalid form: #{form.inspect}"
      end
    end

    private

    def eval_array(form, env)
      form.map { |x| Kigo.eval(x, env) }
    end
  
    def eval_set(form, env)
      form.reduce(Set.new) { |set, x| set << Kigo.eval(x, env) }
    end
  
    def eval_hash(form, env)
      form.reduce({}) { |hash, (k, v)| hash.merge!(Kigo.eval(k, env) => Kigo.eval(v, env)) }
    end
  
    def eval_symbol(form, env)
      string = form.to_s
      return env.lookup_value!(form) unless string.include?(Reader::PERIOD)
  
      MethodDispatch.parse(string, env)
    end
  
    def eval_application(form, env)
      callable = Kigo.eval(form.first, env)
      args     = parse_args(form.next || [], env)
  
      raise SyntaxError, "invalid execution context for macros" if Macro === callable
  
      Kigo.apply(callable, args)
    end

    def parse_args(list, env)
      list.flat_map do |x|
        str = x.to_s
        if str.start_with?('*')
          Kigo.eval(str[1, str.length].to_sym, env).map { |x| { value: x } }
        else
          { value: Kigo.eval(x, env) }
        end
      end.map { |x| x[:value] }
    end

    public

    class Syntax
      def self.tag(name = self.to_s.split('::').last.downcase.to_sym)
        @tag ||= name
      end

      def self.forms
        @forms ||= {}
      end

      def self.inherited(subclass)
        forms[subclass.tag] = subclass if subclass.tag
      end

      def evaluate(env)
        raise "Not implemented"
      end

      def parse_args(list, env)
        list.flat_map do |x|
          str = x.to_s
          if str.start_with?('*')
            Kigo.eval(str[1, str.length].to_sym, env).map { |x| { value: x } }
          else
            { value: Kigo.eval(x, env) }
          end
        end.map { |x| x[:value] }
      end    
    end

    class Quote < Syntax
      attr_reader :form

      def self.parse(form)
        if form.size != 1
          raise ArgumentError, "wrong number of arguments expected 1 got #{form.size - 1}"
        end

        new(form[1])
      end

      def initialize(form)
        @form = form
      end

      def evaluate(env)
        form
      end
    end

    class Def < Syntax
      attr_reader :name, :value

      def self.parse(form)
        if form.size < 2 or form.size > 3
          raise ArgumentError, "wrong number of arguments expcted 1 or 2 got #{form.size - 1}"
        end

        new(form[1], form[2])
      end

      def initialize(name, value)
        @name  = name
        @value = value
      end

      def evaluate(env)
        env.define(name, value)
      end
    end

    class Assignment < Syntax
      tag :set!

      attr_reader :subject, :value

      def self.parse(form)
        if form.size != 3
          raise ArgumentError, "wrong number of arguments expected 2 got #{form.size - 1}"
        end

        new(form[1], form[2])
      end

      def initialize(subject, value)
        @subject = subject
        @value   = value
      end

      def evaluate(env)
        string = subject.to_s
        unless string.include?('.')
          scope = env.lookup!(subject)
          val   = scope.value(subject)

          if val.respond_to?(:set!)
            return val.set!(value)
          else
            return scope.define(subject, value)
          end
        end

        res = MethodDispatch.parse(subject.to_s, env)
        res.subject.send(:"#{res.method}=", value)
        res.subject
      end
    end

    class Lambda < Syntax
      attr_reader :arglist, :body

      def self.parse(form)
        raise ArgumentError, "wrong number of arguments expected 1 or more got #{form.count}" if form.count < 2
        
        new(form[1], form.next.next)
      end

      def initialize(arglist, body)
        @arglist = arglist
        @body = body || Cons.empty
      end

      def evaluate(env)
        # TODO: add some syntatic analysis
        Kigo::Lambda.new(arglist, body, env)
      end
    end

    class Cond < Syntax
      attr_reader :expressions

      def self.parse(form)
        raise "cond should have an even number of elements" if form.next.count.odd?
        
        new(form.next)
      end

      def initialize(expressions)
        @expressions = expressions
      end

      def evaluate(env)
        return nil if expressions.nil?

        result = nil

        expressions.each_slice(2) do |(predicate, consequent)|
          if predicate == :else or Kigo.eval(predicate, env)
            result = Kigo.eval(consequent, env)
            break
          end
        end

        result
      end
    end

    class Send < Syntax
      attr_reader :subject, :method, :args

      def self.parse(form)
        raise ArgumentError, "wrong number of arugments got #{form.count - 1}, expected 2 or 3" if form.count < 3
        
        new(form[1], form[2], form.next.next.next)
      end

      def initialize(subject, method, args)
        @subject = subject
        @method  = method
        @args    = args
      end

      def evaluate(env)
        subject_ = Kigo.eval(subject, env)
        method_  = Kigo.eval(method, env)
        args_    = parse_args(args || [], env)
        last     = args_.last

        if Lambda === last
          subject_.send(method_, *args_.take(args_.size - 1), &last)
        else
          subject_.send(method_, *args_)
        end
      end
    end

    class Macro < Syntax
      tag nil

      def self.parse(form)
        new()
      end

      def evaluate(env)
        env.define(:'*env*', env)
        env.define(:'*form*', form)
        call(*form.to_a)
      end
    end
  end
end