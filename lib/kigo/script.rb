module Kigo
  module_function

  SPECIAL_FORMS = Set[:def, :quote, :send, :set!, :cond, :lambda, :macro, :block].freeze

  def macroexpand1(form, env = Environment.top_level)
    return form unless Cons === form && !SPECIAL_FORMS.include?(form.first)

    value = eval(form.first, env)
    if Macro === value
      value.call(form, env, *form.next.to_a)
    else
      form
    end
  end

  def eval(form, env = Environment.top_level)
    case form
    when String, Numeric, true, false, nil
      form
    else
      tag = form.class.name.split('::').last
      public_send(tag, form, env)
    end
  end

  def method_missing(method, form, env)
    raise RuntimeError, "Invalid form: #{form.inspect}:#{form.class}"
  end

  def Keyword(form, env)
    form.symbol
  end

  def Array(form, env)
    form.map { |x| Kigo.eval(x, env) }
  end

  def Set(form, env)
    form.reduce(Set.new) { |set, x| set << Kigo.eval(x, env) }
  end

  def Hash(form, env)
    form.reduce({}) do |hash, (k, v)|
      hash.merge!(Kigo.eval(k, env) => Kigo.eval(v, env))
    end
  end

  def Symbol(form, env)
    env.lookup_value!(form)
  end

  def Cons(form, env)
    return Cons.empty if form.empty?

    Script.eval(form, env)
  end

  module Script
    module_function

    def eval(form, env)
      raise "Invalid form: #{form}" unless Cons === form

      case form.first
      when Symbol
        tag = form.first.name.upcase
        public_send(tag, form, env)
      else
        APPLICATION(form, env)
      end
    end

    def QUOTE(form, env)
      form.next.first
    end

    def DEF(form, env)
      env.define(form.next.first, Kigo.eval(form.next.next.first, env))
    end

    def SET!(form, env)
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

    def LAMBDA(form, env)
      raise ArgumentError, "wrong number of arguments expected 1 or more got #{form.count}" if form.count < 2

      arglist = form.next.first
      body    = form.next.next || Cons.empty

      Lambda.new(arglist, body, env)
    end

    def COND(form, env)
      return if form.next.nil?
      raise "cond should have an even number of elements" if form.next.count.odd?

      result = nil
      form.next.each_slice(2) do |(predicate, consequent)|
        if predicate == :else or Kigo.eval(predicate, env)
          result = Kigo.eval(consequent, env)
          break
        end
      end

      result
    end

    def SEND(form, env)
      raise ArgumentError, "wrong number of arguments got #{form.count - 1}, expected 2 or 3" if form.count < 3

      subject = Kigo.eval(form.next.first, env)
      method  = Kigo.eval(form.next.next.first, env)
      args    = parse_args(form.next.next.next || [], env)
      last    = args.last

      if last.is_a?(Cons) && last.first == :block
        subject.send(method, *args.take(args.size - 1), &last.next.first)
      else
        subject.send(method, *args)
      end
    end

    def BLOCK(form, env)
      Cons[form.first, Kigo.eval(form.next.first, env)]
    end

    def MACRO(form, env)
      Macro.new(form.next.first, form.next.next, env)
    end

    def method_missing(method, form, env)
      APPLICATION(form, env)
    end

    def APPLICATION(form, env)
      tag = form[0].to_s
      if tag.include?(Reader::PERIOD)
        return MethodDispatch.parse(tag, env).call(*form.rest.to_a)
      end

      SEND(Cons[:send, *form.to_a], env)
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
end
