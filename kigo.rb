# froze_string_literal: true
require 'singleton'

module Kigo
  extend self

  def eval_string(string)
    last = nil
    Reader.new(string).tap do |r|
      until r.eof?
        form = r.next!
        begin
          last = Kigo.eval(form, Environment.top_level)
        rescue Kigo::RuntimeError => e
          raise "Kigo error on line #{r.line}, column #{r.column}: #{e.message}"
        end
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
        array << r.next!
      end
    end
    array
  end

  def eval(form, env = Environment.top_level)
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
      when :fn
        eval_function(form, env)
      when :cond
        eval_cond(form, env)
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

  def eval_function(form, env)
    Lambda.new(form.next.first, form.next.next, env)
  end

  def eval_macro(form, env)
    Macro.new(form.next.first, form.next.next, env)
  end

  def eval_cond(form, env)
    raise "cond should have an even number of elements" if form.next.count.odd?

    form.next.each_slice(2) do |(predicate, consequent)|

    end
  end

  def eval_application(form, env)
    callable = Kigo.eval(form.first, env)
    args     = form.next&.map { |x| Kigo.eval(x, env) } || []

    raise "Invalid execution context for macros" if Macro === callable

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

    def subject
      @subject_value ||= @env.lookup_value!(@subject)
    end

    def call(*args)
      subject.send(method, *args)
    end
  end

  class Lambda
    def initialize(args, code, env)
      @args = args
      @code = code
      @env  = env
    end
    
    def call(*args)
      scope = @env.branch
      @args.each_with_index do |arg, i|
        scope.define(arg, args[i])
      end

      value = nil
      @code.each do |form|
        value = Kigo.eval(form, scope)
      end
      value
    end
  end

  Macro = Class.new(Lambda)

  RuntimeError = Class.new(RuntimeError)

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
    return nil if xs.nil? or xs.empty?

    xs.next
  end

  def self.rest(xs)
    return Cons.empty if xs.nil? or xs.empty?

    xs.next
  end

  CORE_FUNCTIONS = {
    :+   => ->(*args) { args.sum },
    :-   => ->(a, b) { a - b },
    :*   => ->(a, b) { a * b },
    :/   => ->(a, b) { a / b },
    :<   => ->(a, b) { a < b },
    :>   => ->(a, b) { a > b },
    :>=  => ->(a, b) { a >= b },
    :<=  => ->(a, b) { a <= b },
    :'=' => ->(a, b) { a == b },

    # Array
    :array => ->(*args) { args },

    # Hash
    :'hash' => ->(*args) { args.each_slice(2).to_h },

    # Set
    :set => ->(*args) { Set.new(args) },

    # lists
    :list  => ->(*args) { Cons[*args] },
    :cons  => ->(x, xs) { cons(x, xs) },
    :first => ->(xs) { first(xs) },
    :next  => ->(xs) { self.next(xs) },
    :rest  => ->(xs) { rest(xs) },

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
      if empty?
        self.class.new(x, nil, 1)
      else
        self.class.new(x, self, count + 1)
      end
    end

    def each
      xs = self
      until xs.nil?
        yield xs.car
        xs = xs.cdr
      end
    end

    def empty?
      car.nil? && cdr.nil?
    end

    def to_s
      "(#{reduce(nil) { |str, x| str.nil? ? x.to_s : "#{str} #{x}" }})"
    end

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
      @line     = 0
      @column   = 0
    end

    def next!
      return :eof if eof?

      if whitespace?(current_token) # ignore whitespace
        next_token! while whitespace?(current_token)
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
        raise "Invalid token #{current_token.inspect} at line #{@line} column #{@position + 1}"
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
      return Cons.empty if next_token == CLOSE_PAREN

      array = []
      first_line = line
      while true
        next_token! while whitespace?(current_token)

        if current_token == CLOSE_PAREN
          next_token!
          break
        end

        raise "EOF while reading list, starting at: #{first_line}" if current_token.nil?

        array << self.next!
      end

      Cons[*array]
    end

    def read_array!
      array = []
      return array if next_token == CLOSE_BRACKET

      next_token! while whitespace?(current_token)

      until current_token == CLOSE_BRACKET or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
      end
      next_token!

      array
    end

    def read_hash!
      return {} if next_token == CLOSE_BRACE

      next_token! while whitespace?(current_token)

      array = []
      until current_token == CLOSE_BRACE or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
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
        @column  = 0
      else
        @column += 1
      end

      @position += 1
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

class Person
  attr_reader :attributes

  def initialize(attributes = {})
    @attributes = attributes
  end

  def name=(name)
    @attributes[:name] = name
  end
end