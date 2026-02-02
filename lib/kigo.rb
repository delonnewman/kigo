# froze_string_literal: true
require 'set'
require 'singleton'
require 'stringio'

require_relative 'kigo/var'
require_relative 'kigo/cons'
require_relative 'kigo/keyword'
require_relative 'kigo/lambda'
require_relative 'kigo/macro'
require_relative 'kigo/reader'
require_relative 'kigo/evaluator'

module Kigo
  module_function

  RuntimeError  = Class.new(::RuntimeError)
  ArgumentError = Class.new(RuntimeError)
  SyntaxError   = Class.new(RuntimeError)
  TypeError     = Class.new(RuntimeError)

  def current_module
    @current_module ||= Var.new(Kigo, dynamic: true)
  end

  def eval_string(string, env)
    last = nil
    Reader.new(string).tap do |r|
      until r.eof?
        form = r.next!
        next if form == r

        last = Kigo.eval(form, env)
      end
    end
    last
  end

  def eval_file(file, **kwargs)
    eval_string(File.read(file, **kwargs), binding)
  end

  def read(string)
    Reader.new(string)
  end

  def read_string(string)
    array = []
    Reader.new(string).tap do |r|
      until r.eof?
        form = r.next!
        next if form == r

        array << form
      end
    end
    array
  end
end

Kigo.eval_file(File.join(__dir__, 'core.kigo'), encoding: 'filesystem')

#string = '"test" 1 + read * / @ ^hey (1 2 (3 4))'
#
#Kigo::Reader.new(string).tap do |r|
#  until r.eof?
#    value = r.next!
#    pp value
#    puts value
#  end
#end
#
#puts Kigo::Cons.empty.cons(1).cons(2).to_s

#Reader.new(string).tap do |r|
#  until r.current_token.nil?
#    p r.current_token
#    r.next_token!
#  end
#end

#class Person
#  attr_reader :attributes
#
#  def initialize(attributes = {})
#    @attributes = attributes
#  end
#
#  def name=(name)
#    @attributes[:name] = name
#  end
#end
