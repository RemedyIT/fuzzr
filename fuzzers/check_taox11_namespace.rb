# encoding: utf-8
# -------------------------------------------------------------------
# check_taox11_namespace.rb - TAOX11 namespace checker
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzzers
  class TAOX11NamespaceChecker
    include Fuzz::Fzzr
    def initialize
      @fuzz_id = :check_taox11_namespace
      @description = 'checks against the use of the TAOX11_NAMESPACE macro in user/test code'
      @errormsg = 'detected use TAOX11_xxx namespace macro'
    end

    OBJECT_EXTS = ['h', 'hxx', 'hpp', 'c', 'cc', 'cxx', 'cpp', 'H', 'C']

    def applies_to?(object)
      Fuzz::FileObject === object &&
        OBJECT_EXTS.include?(object.ext) &&
        !is_excluded?(object)
    end

    def run(object, apply_fix)
      object.iterate(fuzz_id) do |lnptr|
        if lnptr.text =~ /(TAOX11_NAMESPACE|TAOX11_CORBA|TAOX11_PORTABLE_SERVER)::/ ||
           lnptr.text =~ /namespace\s+(TAOX11_NAMESPACE|TAOX11_CORBA|TAOX11_PORTABLE_SERVER)/
          lnptr.mark_error
        end
      end
    end
  end

  Fuzz.register_fzzr(TAOX11NamespaceChecker.new)
end
