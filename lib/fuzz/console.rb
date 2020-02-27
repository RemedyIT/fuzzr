#--------------------------------------------------------------------
# @file    console.rb
# @author  Martin Corino
#
# @brief   Fuzz console wrapper
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fuzz/screen'

module Fuzz

  module Console

    class << self
      def screen
        @screen ||= Screen.new(Fuzz.options[:output] || $stdout, $stdin)
      end
      include Screen::ColorizeMethods
    end

    def self.print(*args)
      screen.print(*args)
    end

    def self.println(*args)
      screen.println(*args)
    end

    def self.error_print(*args)
      screen.error_print(*args)
    end

    def self.error_println(*args)
      screen.error_println(*args)
    end

    def self.colorizer_include
      Screen::ColorizeMethods
    end

    def self.display_break
      println("\n")
    end

    def self.display_hline(len = nil)
      println("#{'-' * (len || [80, (screen.output_cols / 5 * 4)].min)}\n")
    end

  end # Console

end # Fuzz
