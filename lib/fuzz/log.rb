#--------------------------------------------------------------------
# @file    log.rb
# @author  Martin Corino
#
# @brief   Fuzz logging support
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'fuzz/console'

module Fuzz

  #
  # Default Reporting/Logging
  #
  class Reporter
    def initialize(output = Fuzz::Console)
      @output = output
      klass = class << self; self; end
      klass.__send__(:include, @output.colorizer_include)
    end

    attr_reader :output

    def log_error(msg)
      output.error_println 'Fuzz - ', red(bold 'ERROR'), ' : ', msg
    end

    def log_warning(msg)
      output.error_println 'Fuzz - ', yellow(bold 'WARNING'), ' : ', msg
    end

    def log_info(msg)
      output.println 'Fuzz - ', msg
    end

    def show_error(msg)
      log_error(msg)
    end

    def show_warning(msg)
      log_error(msg)
    end

    def show_msg(msg)
      log(msg)
    end
  end

  module LogMethods
    def log_fatal(msg, rc=1)
      Fuzz.reporter.log_error(msg)
      exit rc
    end

    def log_error(msg)
      Fuzz.reporter.log_error(msg)
    end

    def log_warning(msg)
      Fuzz.reporter.log_warning(msg)
    end

    def log_info(msg)
      Fuzz.reporter.log_info(msg)
    end

    def log(lvl, msg)
      Fuzz.reporter.log_info(msg) if lvl <= verbosity
    end

    def show_error(msg)
      Fuzz.reporter.show_error(msg)
    end

    def show_warning(msg)
      Fuzz.reporter.show_warning(msg)
    end

    def show_msg(msg)
      Fuzz.reporter.show_msg(msg)
    end

    def verbosity
      Fuzz.verbosity
    end

    def verbose?
      verbosity > 1
    end

    def silent?
      verbosity < 1
    end
  end

end # Fuzz
