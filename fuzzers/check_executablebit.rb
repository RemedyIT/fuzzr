# encoding: utf-8
# -------------------------------------------------------------------
# check_executablebit.rb - executable bit checker
#
# Author: Johnny Willemsen
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzzers
  class ExecutablebitChecker
    include Fuzz::Fzzr
    def initialize
      @fuzz_id = :check_executablebit
      @description = 'checks for executable bit set'
    end

    OBJECT_EXTS = ['pl', 'sh', 'bat']

    def applies_to?(object)
      Fuzz::FileObject === object &&
        OBJECT_EXTS.include?(object.ext) &&
        !is_excluded?(object)
    end

    def run(object, apply_fix)
      if !File::executable?(object.path)
        Fuzz.log_error(%Q{#{object.path} - lacks executable bit})
        false
      end
      true
    end

  end

  Fuzz.register_fzzr(ExecutablebitChecker.new)
end
