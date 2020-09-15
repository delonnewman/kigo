module Kigo
  module Core
  def cons(x, xs)
    return Cons.empty.cons(x) if xs.nil?
    return xs.cons(x)         if xs.respond_to?(:cons)

    Cons[*xs.to_a].cons(x)
  end

  def first(xs)
    return nil if xs.nil?

    xs.first
  end

  def next(xs)
    return nil     if xs.nil?
    return nil     if xs.respond_to?(:empty?) && xs.empty?
    return xs.next if Cons === xs

    value = xs.drop(1)
    return nil if value.empty?

    value
  end

  def rest(xs)
    return Cons.empty if xs.nil?
    return Cons.empty if xs.respond_to?(:empty?) && xs.empty?

    value = self.next(xs)
    return Cons.empty if value.nil?

    value
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

    :macroexpand1 => ->(form) { Kigo.macroexpand1(form) }, 
    :eval => ->(form) { Kigo.eval(form) },

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
    :puts => ->(*args) { puts *args },
    :p    => ->(*args) { p *args },
    :pp   => ->(*args) { pp *args }
  }
  end
end