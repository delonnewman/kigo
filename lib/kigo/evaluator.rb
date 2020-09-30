require 'forwardable'

module Kigo
  class Evaluator
    attr_reader :form, :env

    def initialize(form, env = Environment.top_level)
      @form = form
      @env  = env
    end

    def evaluate
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
          evaluator.new(self, form).tap(&:validate!).evaluate
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

    public

    class Syntax
      extend Forwardable

      def_delegator :@evaluator, :env

      attr_reader :evaluator

      def self.tag(name = self.to_s.split('::').last.downcase.to_sym)
        @tag ||= name
      end

      def self.forms
        @forms ||= {}
      end

      def self.inherited(subclass)
        forms[subclass.tag] = subclass if subclass.tag
      end

      def initialize(evaluator, form)
        @form      = form
        @evaluator = evaluator
      end

      def evaluate
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
      def validate!
        if form.size != 1
          raise ArgumentError, "wrong number of arguments expcted 1 got #{form.size - 1}"
        end
      end

      def evaluate
        form.next.first
      end
    end

    class Def < Syntax
      def validate!
        if form.size < 2 or form.size > 3
          raise ArgumentError, "wrong number of arguments expcted 1 or 2 got #{form.size - 1}"
        end
      end

      def evaluate
        env.define(form.next.first, form.next.next.first)
      end
    end

    class Assignment < Syntax
      tag :set!

      def validate!
        if form.size != 2
          raise ArgumentError, "wrong number of arguments expcted 2 got #{form.size - 1}"
        end
      end

      def evaluate
        subject = form.next.first
        value   = form.next.next&.first

        string = subject.to_s
        unless string.include?(Reader::PERIOD)
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
      def validate!
        raise ArgumentError, "wrong number of arguments expected 1 or more got #{form.count}" if form.count < 2
      end

      def evaluate
        arglist = form.next.first
        body    = form.next.next || Cons.empty

        Kigo::Lambda.new(arglist, body, env)
      end
    end

    class Cond < Syntax
      def validate!
        raise "cond should have an even number of elements" if form.next.count.odd?
      end

      def evaluate
        return nil if form.next.nil?

        result = nil
        form.next.each_slice(2) do |(predicate, consequent)|
          if predicate == :else or Kigo.eval(predicate, env)
            result = Kigo.eval(consequent, env)
            break
          end
        end

        result
      end
    end

    class Send < Syntax
      def validate!
        raise ArgumentError, "wrong number of arugments got #{form.count - 1}, expected 2 or 3" if form.count < 3
      end

      def evaluate
        subject = Kigo.eval(form.next.first, env)
        method  = Kigo.eval(form.next.next.first, env)
        args    = parse_args(form.next.next.next || [], env)
        last    = args.last

        if Lambda === last
          subject.send(method, *args.take(args.size - 1), &last)
        else
          subject.send(method, *args)
        end
      end
    end

    class Macro < Syntax
      tag nil

      def validate!
      end

      def evaluate
        env.define(:'*env*', env)
        env.define(:'*form*', form)
        call(*form.to_a)
      end
    end
  end
end