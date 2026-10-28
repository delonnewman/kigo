module Kigo
  class Config
    %i[sbcl_path kernel_path log_level log_path].each do |attribute| 
      attr_writer attribute

      class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{attribute}
          raise "#{attribute} has not been set" unless @#{attribute}

          @#{attribute}
        end
      RUBY

      def root_path
        @root_path ||= Pathname.new(__dir__).join('../..')
      end
    end
  end
end

__END__

Kigo::Config.new do |config|
  config.sbcl_path = '/opt/homebrew/bin/sbcl'
end
