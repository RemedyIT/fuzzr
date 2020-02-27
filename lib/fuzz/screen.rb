#--------------------------------------------------------------------
# @file    screen.rb
# @author  Martin Corino
#
# @brief   Fuzz screen wrapper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fuzz/system'

module Fuzz

  class Screen

    class Color
      def initialize(code)
        @code = code
      end
      attr_reader :code
      def to_s
        ''
      end
      alias :to_str :to_s
    end

    COLORS = {
      black:    [Color.new("\e[30m"), Color.new("\e[m")],
      red:      [Color.new("\e[31m"), Color.new("\e[m")],
      green:    [Color.new("\e[32m"), Color.new("\e[m")],
      yellow:   [Color.new("\e[33m"), Color.new("\e[m")],
      blue:     [Color.new("\e[34m"), Color.new("\e[m")],
      magenta:  [Color.new("\e[34m"), Color.new("\e[m")],
      bold:     [Color.new("\e[1m"),  Color.new("\e[m")],
      reverse:  [Color.new("\e[7m"),  Color.new("\e[m")],
      underline:[Color.new("\e[4m"),  Color.new("\e[m")]
    }

    module ColorizeMethods
      def self.included(mod)
        Screen::COLORS.keys.each do |color|
          mod.module_eval <<-EOT, __FILE__, __LINE__+1
            def #{color}(s)
              [Fuzz::Screen::COLORS[:#{color}].first, s, Fuzz::Screen::COLORS[:#{color}].last]
            end
          EOT
        end
      end
    end

    def initialize(output = STDOUT, input = STDIN, errout = STDERR)
      @output = output
      @input = input
      @errout = errout
      @colorize = output.tty? && Fuzz::Sys.has_ansi?
    end

    attr_reader :input, :output, :errout

    def colorize?
      @colorize
    end

    def output_cols
      80
    end

    def print(*args)
      output.print args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def println(*args)
      output.puts args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def error_print(*args)
      errout.print args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

    def error_println(*args)
      errout.puts args.flatten.collect {|a| (colorize? && Color === a) ? a.code : a }.join
    end

  end # Screen

end # Fuzz
