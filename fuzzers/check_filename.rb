# encoding: utf-8
# -------------------------------------------------------------------
# check_filename.rb - TAOX11 filename fuzzer
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT  Expertise BV
# -------------------------------------------------------------------

module Fuzzers
  class FilenameChecker
    include Fuzz::Fzzr
    def initialize
      @fuzz_id = :check_filename
      @description = 'checks against the use of uppercase in file/directory names'
    end

    def applies_to?(object)
      !is_excluded?(object)
    end

    def run(object, apply_fix)
      if object.name =~ /[A-Z]/
        Fuzz.log_error(%Q{name for #{object.path} contains uppercase})
        false
      else
        true
      end
    end
  end

  Fuzz.register_fzzr(FilenameChecker.new)
end
