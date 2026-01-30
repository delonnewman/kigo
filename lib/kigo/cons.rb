module Kigo
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

    alias :size :count
    alias :length :count

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

    def [](n)
      return nil     if empty?
      return car     if n == 0
      return cdr.car if n == 1

      cdr[n - 1]
    end

    def ==(other)
      return false unless Cons === other
      return false unless count == other.count
      return false unless car == other.car

      cdr == other.cdr
    end

    def empty?
      car.nil? && cdr.nil?
    end
  
    def join(delimiter)
      reduce(nil) { |str, x| str.nil? ? x.to_s : "#{str}#{delimiter}#{x}" }
    end

    def to_s
      "(#{map(&:inspect).join(' ')})"
    end
    alias inspect to_s

    alias first car
    alias next cdr

    def rest
      return cdr unless cdr.nil?

      self.class.empty
    end
  end
end
