require 'prism'

module Kigo
  def self.compile_string(code, file: nil)
    result = Prism.parse(code, freeze: true, filepath: file)
    compile(result.value)
  end

  # FIXME: Prism off-by-one error Prism.parse('1 2 3 4').value.statements.body.map(&:value) # => [2, 3, 3, 4]
  def self.compile(node)
    case node
    when Prism::ProgramNode
      "(progn #{compile(node.statements)})"
    when Prism::StatementsNode
      node.body.map { compile(it) }.join(' ')
    when Prism::IntegerNode
      node.slice
    when Prism::ParenthesesNode
      "(progn #{compile(node.body)})"
    when Prism::CallNode
      case node.name
      when :+, :-, :*, :/, :<, :>, :<=, :>=
        "(#{node.name} #{compile(node.receiver)} #{compile(node.arguments.arguments.first)})"
      when :%
        "(mod #{compile(node.receiver)} #{compile(node.arguments.arguments.first)})"
      else
        raise "unknown method call #{node}:#{node.name}"
      end
    else
      raise "unknown node #{node}:#{node.class}"
    end
  end
end

__END__

Prism.parse('(1 - (6 - 5))').value.statements.body.first.body.body
Kigo.compile_string('(1 - (6 - 5))')
Kigo.compile_string('(1 - 6 - 5)')
