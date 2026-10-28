require_relative '../src/kigo'

Kigo.configure do |config|
  config.sbcl_path   = '/opt/homebrew/bin/sbcl'
  config.kernel_path = config.root_path.join('lib/kernel.lisp')
  config.log_path    = config.root_path.join('logs/development.log')
  config.log_level   = :info
end

