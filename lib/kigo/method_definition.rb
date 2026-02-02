module Kigo
  class MethodDefinition
    attr_reader :method, :args, :body 

    def self.from_data(form)
      raise ArgumentError, "invalid form expected: (def NAME ARGS *BODY)" unless form.length > 3
      
      method = form[1]
      if method.is_a?(Cons)
        (receiver, method) = method.to_a
      end
      new(receiver:, method:, args: form[2], body: form.drop(3))
    end
    
    def initialize(receiver: nil, method:, args:, body:)
      @receiver = receiver
      @method   = method
      @args     = args
      @body     = body
    end

    def instance_method?
      @receiver.nil?
    end

    def singleton_method?
      !!instance_method?
    end

    def receiver
      @receiver || Kernel
    end

    def body_proc
      args = self.args
      body = self.body
      lambda do |*params| 
        args.each_with_index do |arg, i| 
          binding.local_variable_set(arg, params[i])
        end
        result = nil
        body.each do |line|
          result = Kigo.eval(line, binding)
        end
        result
      end
    end
  end
end
