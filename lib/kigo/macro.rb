module Kigo
  class Macro < Lambda
    def call(form, env, *args)
      @env.define(:'*form*', form)
      @env.define(:'*env*', env)
      super(*args)
    end

    def to_s
      Cons.new(:macro, Cons.new(@arglist, Cons.new(@code, Cons.empty))).to_s
    end
    alias inspect to_s
  end
end