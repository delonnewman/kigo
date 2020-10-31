# froze_string_literal: true
require 'set'
require 'singleton'
require 'stringio'

require_relative 'kigo/core'
require_relative 'kigo/var'
require_relative 'kigo/cons'
require_relative 'kigo/keyword'
require_relative 'kigo/lambda'
require_relative 'kigo/macro'
require_relative 'kigo/method_dispatch'
require_relative 'kigo/reader'
require_relative 'kigo/environment'
require_relative 'kigo/evaluator'

module Kigo
  extend self

  RuntimeError  = Class.new(::RuntimeError)
  ArgumentError = Class.new(RuntimeError)
  SyntaxError   = Class.new(RuntimeError)
  TypeError     = Class.new(RuntimeError)

  def current_module
    @current_module ||= Var.new(Kigo::Core, dynamic: true)
  end

  def eval_string(string, env = Environment.top_level)
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

  def eval_file(file)
    eval_string(IO.read(file, encoding: 'UTF-8'))
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

  def evaluator(env)
    @evaluators ||= {}
    @evaluators[env.object_id] ||= Kigo::Evaluator.new(env)
  end

  def eval(form, env = Environment.top_level)
    evaluator(env).evaluate(form)
  end

  def apply(callable, args)
    args = args.to_a
    
    return callable[*args]          if callable.respond_to?(:[])
    return callable.include?(*args) if callable.respond_to?(:include?)

    callable.call(*args)
  end
end

Kigo::Environment.top_level.define(:'*module*', Kigo.current_module)
Kigo.eval_file(File.join(__dir__, 'core.kigo'))

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
