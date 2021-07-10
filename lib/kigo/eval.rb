# froze_string_literal: true
module Kigo
  extend self

  SPECIAL_FORMS = Set[:def, :quote, :send, :set!, :cond, :lambda, :macro, :'block-coerce'].freeze

  def macroexpand1(form, env = Environment.top_level)
    if Cons === form && !SPECIAL_FORMS.include?(form.first)
      value = eval(form.first, env)
      if Macro === value
        value.call(form, env, *form.next.to_a)
      else
        form
      end
    else
      form
    end
  end

  def eval(form, env = Environment.top_level)
    form = macroexpand1(form, env)
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

      case form.first
      when :quote
        form.next.first
      when :def
        eval_definition(form, env)
      when :set!
        eval_assignment(form, env)
      when :lambda
        eval_lambda(form, env)
      when :cond
        eval_cond(form, env)
      when :send
        eval_send(form, env)
      when :'block-coerce'
        Cons.new(form.first, eval(form.next.first, env))
      when :macro
        eval_macro(form, env)
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

  def eval_definition(form, env)
    env.define(form.next.first, Kigo.eval(form.next.next.first, env))
  end

  # (def x 1)
  # (is (= x 1))
  # (set! x 2)
  #
  # (Person.new {:name "Delon"})
  #
  # (def person Person.new)
  # (set! person.name "Jackie")
  #
  # TODO: (set! (names 0) "Delon") => names[0] = "Delon"
  def eval_assignment(form, env)
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

  def eval_lambda(form, env)
    raise ArgumentError, "wrong number of arguments expected 1 or more got #{form.count}" if form.count < 2

    arglist = form.next.first
    body    = form.next.next || Cons.empty

    Lambda.new(arglist, body, env)
  end

  def eval_macro(form, env)
    Macro.new(form.next.first, form.next.next, env)
  end

  def eval_cond(form, env)
    return nil if form.next.nil?
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

  def eval_send(form, env)
    raise ArgumentError, "wrong number of arugments got #{form.count - 1}, expected 2 or 3" if form.count < 3

    subject = Kigo.eval(form.next.first, env)
    method  = Kigo.eval(form.next.next.first, env)
    args    = parse_args(form.next.next.next || [], env)
    last    = args.last

    if last.is_a?(Cons) && last.first == :'block-coerce'
      subject.send(method, *args.take(args.size - 1), &last.next)
    else
      subject.send(method, *args)
    end
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

  def eval_application(form, env)
    callable = Kigo.eval(form.first, env)
    args     = parse_args(form.next || [], env)

    raise SyntaxError, "invalid execution context for macros" if Macro === callable

    Kigo.apply(callable, args)
  end
end
