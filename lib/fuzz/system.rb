#--------------------------------------------------------------------
# @file    system.rb
# @author  Martin Corino
#
# @brief   System support for Fuzz
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fileutils'

module Fuzz

  module Sys

    module SysMethods

      def mswin?
        /mingw/ =~ RUBY_PLATFORM ? true : false
      end

      def has_ansi?
        # only ANSI escape code support on Windows
        # if ANSICON (https://github.com/adoxa/ansicon) installed
        (!mswin?) || ENV['ANSICON']
      end

      def in_dir(dir, &block)
        STDERR.puts "cd #{dir}" if Fuzz.verbose?
        rc = if Fuzz.dryrun?
          yield if block_given?
        else
          Dir.chdir(dir, &block)
        end
        STDERR.puts "cd -" if Fuzz.verbose?
        rc
      end
      def mv(src, tgt)
        FileUtils.move(src, tgt, :verbose => Fuzz.verbose?)
      end

      def cp(src, tgt)
        FileUtils.copy(src, tgt, :verbose => Fuzz.verbose?)
      end

      def chmod(mode, path)
        FileUtils.chmod(mode, path, :verbose => Fuzz.verbose?)
      end

    end # SysMethods

    class << self
      include Sys::SysMethods
    end

  end # Sys

end # Fuzz
