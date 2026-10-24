module Kigo
  class Config
    attr_writer :sbcl_path

    def sbcl_path
      raise "sbcl_path has not been set" unless @sbcl_path

      @sbcl_path
    end
  end
end

__END__

Kigo::Config.new do |config|
  config.sbcl_path = '/opt/homebrew/bin/sbcl'
end
