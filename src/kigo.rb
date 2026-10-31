require 'prism'

require_relative 'kigo/config'
require_relative 'kigo/sbcl'
require_relative 'kigo/lisp_program'

module Kigo
  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield config if block_given?

    config
  end

  def self.kernel
    @kernel ||= Pathname.new(config.kernel_path)
  end

  def self.log
    @log ||= Logger.new(config.log_path, level: config.log_level, progname: name)
  end

  def self.sbcl
    @sbcl ||= SBCL.new(config.sbcl_path)
  end

  def self.eval_file(file)
    code = File.read(file)
    sbcl.start.eval_string(compile_string(code, file:))
  end

  def self.eval_string(code)
    sbcl.start.eval_string(compile_string(code))
  end

  def self.create_binary(file, output)
    code = File.read(file)
    lisp_code = compile_string(code, file: file)
    sbcl.create_binary(LispProgram.new(lisp_code), output)
  end

  def self.compile_string(code, file: nil)
    result = Prism.parse(code, freeze: true, filepath: file)
    compile(result.value)
  end

  GLOBALS = {
    :$_ => '*rb-topic-variable*'
  }.freeze

  # FIXME: Prism off-by-one error Prism.parse('1 2 3 4').value.statements.body.map(&:value) # => [2, 3, 3, 4]
  def self.compile(node)
    case node
    when Prism::ProgramNode
      "(progn #{compile(node.statements)})"
    when Prism::StatementsNode
      node.body.map { compile(it) }.join(' ')
    when Prism::IntegerNode, Prism::FloatNode
      node.slice
    when Prism::StringNode
      %("#{node.unescaped.gsub(/["\\]/) { "\\#{_1}" }}")
    when Prism::ParenthesesNode
      "(progn #{compile(node.body)})"
    when Prism::GlobalVariableReadNode
      GLOBALS.fetch(node.name) do
        binding.irb
        raise "unknown global #{node.name}"
      end
    when Prism::CallNode
      return compile_call(node) if !node.receiver && Kernel.respond_to?(node.name)

      case node.name
      when :+, :-, :*, :/, :<, :>, :<=, :>=
        "(#{node.name} #{compile(node.receiver)} #{compile(node.arguments.arguments.first)})"
      when :%
        "(mod #{compile(node.receiver)} #{compile(node.arguments.arguments.first)})"
      else
        binding.irb
        raise "unknown method call #{node}:#{node.name}"
      end
    else
      binding.irb
      raise "unknown node #{node}:#{node.class}"
    end
  end

  private

  def self.compile_call(node)
    return "(kigo:#{node.name})" unless node.arguments

    "(kigo:#{node.name} #{node.arguments.arguments.map { compile(it) }.join(' ')})"
  end
end

__END__

Prism.parse('(1 - (6 - 5))').value.statements.body.first.body.body
Kigo.compile_string('(1 - (6 - 5))')
Kigo.compile_string('(1 - 6 - 5)')

Kigo.configure do |config| 
  config.sbcl_path = '/opt/homebrew/bin/sbcl'
end

Kigo.config.sbcl_path
Kigo.sbcl.start
Kigo.sbcl.eval_string('(+ 45 90)')
