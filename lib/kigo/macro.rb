module Kigo
  class Macro < Lambda
    def self.from_data(form)
      new(form.next.first, form.next.next)
    end

    def call(form, env, *args)
      self.env.local_variable_set(:_form, form)
      self.env.local_variable_set(:_env, env)
      super(*args)
    end

    def to_s
      Cons.new(:macro, Cons.new(@arglist, @code)).to_s
    end
    alias inspect to_s
  end
end
