module Kigo
  module Core
    module_function

    def cons(x, xs)
      return Cons.empty.cons(x) if xs.nil?
      return xs.cons(x)         if xs.respond_to?(:cons)

      Cons[*xs.to_a].cons(x)
    end

    def first(xs)
      return nil if xs.nil?

      xs.first
    end

    def last(xs)
      return nil if xs.nil?
      return nil if xs.respond_to?(:empty?) && xs.empty?

      xs.last
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

    def array(*args)
      args
    end

    def hash(*args)
      args.each_slice(2).to_h
    end
  end
end