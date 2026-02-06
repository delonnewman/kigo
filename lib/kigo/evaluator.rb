require_relative 'assignment'
require_relative 'conditional'
require_relative 'method_definition'

module Kigo
  module_function

  SPECIAL_FORMS = Set[:def, :quote, :send, :set!, :cond, :lambda, :macro].freeze

  def macroexpand1(form, env)
    return form unless Cons === form && !SPECIAL_FORMS.include?(form.first)

    value = eval(form.first, env)
    if Macro === value
      value.call(form, env, *form.next.to_a)
    else
      form
    end
  end

  def eval(form, env)
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
    return env.receiver if form == :self

    if form[0] =~ /\A[A-Z]/ && Kernel.const_defined?(form)
      return Kernel.const_get(form)
    end

    env.local_variable_get(form)
  end

  def Cons(form, env)
    return Cons.empty if form.empty?

    Form.eval(form, env)
  end

  module Form
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
      definition = MethodDefinition.from_data(form)

      if definition.instance_method?
        definition.receiver.define_method(
          definition.method,
          *definition.args,
          &definition.body_proc
        )
      else
        definition.receiver.define_singleton_method(
          definition.method,
          *definition.args,
          &definition.body_proc
        )
      end

      definition.method
    end

    def SET!(form, env)
      assignment = Assignment.from_data(form)

      if assignment.method_assignment?
        obj = Kigo.eval(assignment.subject[0], env)
        obj.public_send(:"#{assignment.subject[1]}=", Kigo.eval(assignment.value, env))
        return obj
      end

      if assignment.member_assignment?
        obj = Kigo.eval(assignment.subject[0], env)
        key = Kigo.eval(assignment.subject[1], env)
        obj.public_send(:[]=, key, Kigo.eval(assignment.value, env))
        return obj
      end

      if env.local_variable_defined?(assignment.subject)
        val = env.local_variable_get(assignment.subject)
        return val.set!(assignment.value) if val.respond_to?(:set!)
      end

      return env.local_variable_set(assignment.subject, Kigo.eval(assignment.value, env))
    end

    def LAMBDA(form, env)
      syn = Lambda.from_data(form)
      syn.env = env
      syn
    end

    def COND(form, env)
      cond = Conditional.from_data(form)
      return if cond.empty?

      result = nil
      cond.pairs.each do |pair|
        if pair.alternate? or Kigo.eval(pair.predicate, env)
          result = Kigo.eval(pair.consequent, env)
          break
        end
      end

      result
    end

    def SEND(form, env)
      if form.count < 3
        got = form.count - 1
        raise ArgumentError, "wrong number of arguments got #{got}, expected 2 or 3"
      end
      
      subject = Kigo.eval(form[1], env)
      method  = form[2].is_a?(Symbol) ? form[2] : Kigo.eval(form[2], env)
      args    = parse_args(form.drop(3), env)
      last    = args.last

      if last.respond_to?(:to_proc)
        args = args.take(args.size - 1)
        subject.send(method, *args, &last)
      else
        subject.send(method, *args)
      end
    end

    def MACRO(form, env)
      syn = Macro.from_data(form)
      syn.env = env
      syn
    end

    def method_missing(method, form, env)
      APPLICATION(form, env)
    end

    def APPLICATION(form, env)
      tag = form[0]

      if tag.is_a?(Symbol)
        if Kernel.respond_to?(tag)
          return Kernel.public_send(tag, *form.rest.to_a)
        elsif tag[0] =~ /\A[A-Z]/ && Kernel.const_defined?(tag)
          return Kernel::const_get(tag).public_send(*form.rest.to_a)
        end
      end

      tag = Kigo.eval(tag, env)
      if tag.respond_to?(:call)
        args = form.rest.map { |x| Kigo.eval(x, env) }
        return tag.call(*args)
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
