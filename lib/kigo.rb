# froze_string_literal: true
require 'set'
require 'singleton'

module Kigo
  extend self

  RuntimeError  = Class.new(::RuntimeError)
  ArgumentError = Class.new(RuntimeError)
  SyntaxError   = Class.new(RuntimeError)

  def eval_string(string, env = Environment.top_level)
    last = nil
    Reader.new(string).tap do |r|
      until r.eof?
        form = r.next!
        next if form == r
        last = Kigo.eval(form, env)
      end
    end
    last
  end

  def eval_file(file)
    eval_string(IO.read(file))
  end

  def read(string)
    Reader.new(string)
  end

  def read_string(string)
    array = []
    Reader.new(string).tap do |r|
      until r.eof?
        form = r.next!
        next if form == r
        array << form
      end
    end
    array
  end

  SPECIAL_FORMS = Set[:def, :quote, :set!, :send, :cond, :lambda, :macro].freeze

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
        form.next
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
    return env.lookup!(subject).define(value) unless string.include?(Reader::PERIOD)

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
    args    = (form.next.next.next&.to_a || []).map { |x| Kigo.eval(x, env) }

    subject.send(method, *args)
  end

  def eval_application(form, env)
    callable = Kigo.eval(form.first, env)
    args     = form.next&.map { |x| Kigo.eval(x, env) } || []

    raise SyntaxError, "invalid execution context for macros" if Macro === callable

    return callable[*args]          if callable.respond_to?(:[])
    return callable.include?(*args) if callable.respond_to?(:include?)

    callable.call(*args)
  end

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

  class Lambda
    attr_reader :arity

    def initialize(args, code, env)
      @arglist = args
      @code = code
      @env  = env
      parse_arguments!
    end

    def to_s
      Cons.new(:lambda, Cons.new(@arglist, Cons.new(@code, nil))).to_s
    end
    alias inspect to_s
    
    def call(*args)
      scope = @env.branch
      @args.each_with_index do |arg, i|
        if arity < 0 && arity.abs == i + 1
          scope.define(arg, Cons[*args[i, args.length]])
          break
        else
          scope.define(arg, args[i])
        end
      end

      value = nil
      @code.each do |form|
        value = Kigo.eval(form, scope)
      end
      value
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

  class Macro < Lambda
    def call(form, env, *args)
      @env.define(:'*form*', form)
      @env.define(:'*env*', env)
      super(*args)
    end

    def to_s
      Cons.new(:macro, Cons.new(@arglist, Cons.new(@code, nil))).to_s
    end
    alias inspect to_s
  end

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
  end

  class RubyEnvironment < Environment
    include Singleton

    def lookup_value!(symbol)
      Object.const_get(symbol)
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
  end

  def self.cons(x, xs)
    return Cons.empty.cons(x) if xs.nil? or xs.empty?

    xs.cons(x)
  end

  def self.first(xs)
    return nil if xs.nil? or xs.empty?

    xs.first
  end

  def self.next(xs)
    return nil     if xs.nil? or xs.empty?
    return xs.next if Cons === xs

    xs.drop(1)
  end

  def self.rest(xs)
    return Cons.empty if xs.nil? or xs.empty?

    self.next(xs)
  end

  CORE_FUNCTIONS = {
    :+    => ->(*args) { args.sum },
    :-    => ->(a, b) { a - b },
    :*    => ->(a, b) { a * b },
    :/    => ->(a, b) { a / b },
    :<    => ->(a, b) { a < b },
    :>    => ->(a, b) { a > b },
    :>=   => ->(a, b) { a >= b },
    :<=   => ->(a, b) { a <= b },
    :'='  => ->(a, b) { a == b },
    :'==' => ->(a, b) { a === b },

    :eval => -> (form) { Kigo.eval(form) },

    # OOP
    :isa?       => ->(object, klass) { object.is_a?(klass) },
    :'class-of' => ->(object) { object.class },
    :method     => ->(object, name) { object.method(name) },

    # Array
    :array => ->(*args) { args },

    # Hash
    :'hash' => ->(*args) { args.each_slice(2).to_h },

    # Set
    :set          => ->(*args) { Set.new(args) },
    :'sorted-set' => ->(*args) { SortedSet.new(args) },

    # lists
    :list  => ->(*args) { Cons[*args] },
    :cons  => ->(x, xs) { cons(x, xs) },

    :first  => ->(xs) { first(xs) },
    :next   => ->(xs) { self.next(xs) },
    :rest   => ->(xs) { rest(xs) },
    :empty? => ->(xs) { xs.empty? },

    # IO
    :puts => ->(*args) { puts *args }
  }

  CORE_FUNCTIONS.each do |name, value|
    Environment.top_level.define(name, value)
  end

  class Keyword
    attr_reader :symbol

    def initialize(symbol)
      @symbol = symbol
    end
  end

  class Cons
    include Enumerable

    attr_reader :car, :cdr, :count

    def self.[](*elements)
      return empty if elements.empty?

      elements.reverse.reduce(empty, &:cons)
    end

    def self.empty
      @empty ||= new(nil, nil)
    end

    def initialize(car, cdr, count = 0)
      @car   = car
      @cdr   = cdr
      @count = count
    end

    def cons(x)
      self.class.new(x, self, count + 1)
    end

    def each
      xs = self
      until xs.empty?
        yield xs.car
        xs = xs.cdr
      end
    end

    def empty?
      car.nil? && cdr.nil?
    end

    def to_s
      "(#{reduce(nil) { |str, x| str.nil? ? x.inspect : "#{str} #{x.inspect}" }})"
    end
    alias inspect to_s

    alias first car
    alias next cdr
  end

  class Reader
    attr_reader :line

    START_SYMBOL_PAT = /[A-Za-z_\-\*\/\+\&\=\?\^\<\>\%\$\#\@\!\.]/.freeze
    SYMBOL_PAT       = /[A-Za-z0-9_\-\*\/\+\&\=\?\^\<\>\%\$\#\@\!\.]/.freeze
    DIGIT_PAT        = /\d/.freeze
    DOUBLE_QUOTE     = '"'
    OPEN_PAREN       = '('
    CLOSE_PAREN      = ')'
    OPEN_BRACKET     = '['
    CLOSE_BRACKET    = ']'
    OPEN_BRACE       = '{'
    CLOSE_BRACE      = '}'
    PERIOD           = '.'
    SLASH            = '/'
    SPACE            = ' '
    TAB              = "\t"
    NEWLINE          = "\n"
    RETURN           = "\r"
    COMMA            = ','
    EMPTY_STRING     = ''

    def initialize(string)
      @tokens   = string.split('')
      @position = 0
      @line     = 1
      @column   = 1
    end

    def next!
      return self if eof?

      if whitespace?(current_token) # ignore whitespace
        next_token! while whitespace?(current_token)
      end

      if current_token == ';'
        next_token! until current_token == NEWLINE or current_token == RETURN
        next_token!
        return self
      end

      if current_token == DOUBLE_QUOTE
        next_token!
        read_string!
      elsif current_token =~ DIGIT_PAT
        read_number!
      elsif current_token =~ START_SYMBOL_PAT
        read_symbol!
      elsif current_token == ':'
        next_token!
        read_keyword!
      elsif current_token == "'"
        next_token!
        Cons.new(:quote, next!)
      elsif current_token == OPEN_PAREN
        next_token!
        read_list!
      elsif current_token == OPEN_BRACKET
        next_token!
        read_array!
      elsif current_token == OPEN_BRACE
        next_token!
        read_hash!
      else
        raise "Invalid token #{current_token.inspect} at line #{@line} column #{@column}"
      end
    end

    def read_string!
      buffer = StringIO.new

      until current_token == DOUBLE_QUOTE or eof?
        buffer << current_token
        next_token!
      end
      next_token!

      buffer.string
    end

    def read_number!
      buffer = StringIO.new

      while true
        break if current_token !~ /[\d\.\/]/ or eof?

        buffer << current_token
        next_token!
      end

      string = buffer.string
      return string.to_f      if string.include?(PERIOD)
      return rational(string) if string.include?(SLASH)

      string.to_i
    end

    def read_list!
      if current_token == CLOSE_PAREN
        next_token!
        return Cons.empty
      end

      array = []
      first_line = line
      until current_token == CLOSE_PAREN or eof?
        value = self.next!
        array << value
        next_token! while whitespace?(current_token)
        raise "EOF while reading list, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      Cons[*array]
    end

    def read_array!
      array = []
      if current_token == CLOSE_BRACKET
        next_token!
        return array
      end

      next_token! while whitespace?(current_token)

      first_line = line
      until current_token == CLOSE_BRACKET or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
        raise "EOF while reading array, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      array
    end

    def read_hash!
      if current_token == CLOSE_BRACE
        next_token!
        return {}
      end

      next_token! while whitespace?(current_token)

      array = []
      first_line = line
      until current_token == CLOSE_BRACE or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
        raise "EOF while reading hash, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      array.each_slice(2).to_h
    end

    def read_symbol!
      buffer = StringIO.new

      until !symbol_token?(current_token) or eof?
        buffer << current_token
        next_token!
      end

      symbol = buffer.string.to_sym
      return true  if symbol == :true
      return false if symbol == :false
      return nil   if symbol == :nil

      symbol
    end

    def read_keyword!
      buffer = StringIO.new

      until !symbol_token?(current_token) or eof?
        buffer << current_token
        next_token!
      end

      Keyword.new(buffer.string.to_sym)
    end

    def eof?
      @position >= @tokens.size
    end

    def current_token
      @tokens[@position]
    end

    def next_token!
      if current_token == NEWLINE
        @line   += 1
        @column  = 1
      else
        @column += 1
      end

      @position += 1

      self
    end

    def prev_token
      @tokens[@position - 1]
    end

    def next_token
      @tokens[@position + 1]
    end

    def rational(string)
      Rational(*string.split(SLASH).map(&:to_i))
    end

    def whitespace?(token)
      token == SPACE || token == NEWLINE || token == TAB || token == RETURN || token == COMMA # ignore whitespace
    end

    def symbol_token?(token)
      token =~ SYMBOL_PAT
    end
  end
end

Kigo.eval_file(File.join(__dir__, 'core.kigo'))

#string = '"test" 1 + read * / @ ^hey (1 2 (3 4))'
#
#Kigo::Reader.new(string).tap do |r|
#  until r.eof?
#    value = r.next!
#    pp value
#    puts value
#  end
#end
#
#puts Kigo::Cons.empty.cons(1).cons(2).to_s

#Reader.new(string).tap do |r|
#  until r.current_token.nil?
#    p r.current_token
#    r.next_token!
#  end
#end

#class Person
#  attr_reader :attributes
#
#  def initialize(attributes = {})
#    @attributes = attributes
#  end
#
#  def name=(name)
#    @attributes[:name] = name
#  end
#end