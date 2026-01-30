# frozen_string_literal: true
module Kigo
  class Reader
    attr_reader :line

    START_SYMBOL_PAT = /[A-Za-z_\-\*\/\+\=\?\^\<\>\%\$\#\@\!\.]/
    SYMBOL_PAT       = /[A-Za-z0-9_\-\*\/\+\=\?\^\<\>\%\$\#\@\!\.\:]/
    DIGIT_PAT        = /\d/
    DOUBLE_QUOTE     = '"'
    OPEN_PAREN       = '('
    CLOSE_PAREN      = ')'
    OPEN_BRACKET     = '['
    CLOSE_BRACKET    = ']'
    OPEN_BRACE       = '{'
    CLOSE_BRACE      = '}'
    PERIOD           = '.'
    SLASH            = '/'
    SPACE            = ' '
    TAB              = "\t"
    NEWLINE          = "\n"
    RETURN           = "\r"
    COMMA            = ','
    EMPTY_STRING     = ''

    def initialize(string)
      @tokens   = string.split('')
      @position = 0
      @line     = 1
      @column   = 1
    end

    def next!
      return self if eof?

      if whitespace?(current_token) # ignore whitespace
        next_token! while whitespace?(current_token)
      end

      if current_token == ';'
        next_token! until current_token == NEWLINE or current_token == RETURN
        next_token!
        return self
      end

      if current_token == DOUBLE_QUOTE
        next_token!
        read_string!
      elsif current_token =~ DIGIT_PAT
        read_number!
      elsif current_token =~ START_SYMBOL_PAT
        read_symbol!
      elsif current_token == ':'
        next_token!
        read_keyword!
      elsif current_token == "'"
        next_token!
        Cons[:quote, next!]
      elsif current_token == '&'
        next_token!
        Cons[:lambda, Cons[:'*args'], next!]
      elsif current_token == OPEN_PAREN
        next_token!
        read_list!
      elsif current_token == OPEN_BRACKET
        next_token!
        read_array!
      elsif current_token == OPEN_BRACE
        next_token!
        read_hash!
      else
        return self if eof?

        raise "Invalid token #{current_token.inspect} at line #{@line} column #{@column}"
      end
    end

    def read_string!
      buffer = StringIO.new

      until current_token == DOUBLE_QUOTE or eof?
        buffer << current_token
        next_token!
      end
      next_token!

      buffer.string
    end

    def read_number!
      buffer = StringIO.new

      while true
        break if current_token !~ /[\d\.\/]/ or eof?

        buffer << current_token
        next_token!
      end

      string = buffer.string
      return string.to_f      if string.include?(PERIOD)
      return rational(string) if string.include?(SLASH)

      string.to_i
    end

    def read_list!
      if current_token == CLOSE_PAREN
        next_token!
        return Cons.empty
      end

      array = []
      first_line = line
      until current_token == CLOSE_PAREN or eof?
        value = self.next!
        array << value
        next_token! while whitespace?(current_token)
        raise "EOF while reading list, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      Cons[*array]
    end

    def read_array!
      array = []
      if current_token == CLOSE_BRACKET
        next_token!
        return array
      end

      next_token! while whitespace?(current_token)

      first_line = line
      until current_token == CLOSE_BRACKET or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
        raise "EOF while reading array, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      array
    end

    def read_hash!
      if current_token == CLOSE_BRACE
        next_token!
        return {}
      end

      next_token! while whitespace?(current_token)

      array = []
      first_line = line
      until current_token == CLOSE_BRACE or eof?
        array << self.next!
        next_token! while whitespace?(current_token)
        raise "EOF while reading hash, starting at: #{first_line}" if current_token.nil?
      end
      next_token!

      array.each_slice(2).to_h
    end

    def read_symbol!
      buffer = StringIO.new

      until !symbol_token?(current_token) or eof?
        buffer << current_token
        next_token!
      end

      symbol = buffer.string.to_sym
      return true  if symbol == :true
      return false if symbol == :false
      return nil   if symbol == :nil

      symbol
    end

    def read_keyword!
      buffer = StringIO.new

      until !symbol_token?(current_token) or eof?
        buffer << current_token
        next_token!
      end

      Keyword.new(buffer.string.to_sym)
    end

    def eof?
      @position >= @tokens.size
    end

    def current_token
      @tokens[@position]
    end

    def next_token!
      if current_token == NEWLINE
        @line   += 1
        @column  = 1
      else
        @column += 1
      end

      @position += 1

      self
    end

    def prev_token
      @tokens[@position - 1]
    end

    def next_token
      @tokens[@position + 1]
    end

    def rational(string)
      Rational(*string.split(SLASH).map(&:to_i))
    end

    def whitespace?(token)
      token == SPACE || token == NEWLINE || token == TAB || token == RETURN || token == COMMA # ignore whitespace
    end

    def symbol_token?(token)
      token =~ SYMBOL_PAT
    end
  end
end
