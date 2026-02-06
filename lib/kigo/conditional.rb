module Kigo
  class Conditional
    attr_reader :pairs

    def self.from_data(form)
      raise "cond should have an even number of elements" if form.next.count.odd?

      pairs = form.next.each_slice(2).map do |(predicate, consequent)|
        Pair.new(predicate, consequent)
      end

      new(pairs)
    end
    
    def initialize(pairs)
      @pairs = pairs
    end

    def empty?
      pairs.empty?
    end

    class Pair
      attr_reader :predicate, :consequent

      def initialize(predicate, consequent)
        @predicate  = predicate
        @consequent = consequent
      end

      def alternate?
        predicate == :else
      end
    end
  end
end
