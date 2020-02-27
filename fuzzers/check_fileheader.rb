# encoding: utf-8
# -------------------------------------------------------------------
# check_fileheader.rb - TAOX11 file header checker
#
# Author: Marcel Smit
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzzers
  class TAOX11FileHeaderChecker
    include Fuzz::Fzzr
    def initialize
      @fuzz_id = :check_fileheader
      @description = 'checks whether a file contains a correct file header'
      @errormsg = 'incorrect or no fileheader detected. Fileheaders should start on the first or second line, should have a size of 6 lines and the file name should be on the second line of the header.'
    end

    def applies_to?(object)
      Fuzz::FileObject === object &&
        !is_excluded?(object)
    end

    def run(object, apply_fix)
      header_start = nil
      script = false
      object.iterate(fuzz_id) do |lnptr|
        case lnptr.line_nr
        when 1
          if lnptr.text =~ /^(\/[\*]|[#])/
            if not lnptr.text =~ /^(#!)/
              header_start = lnptr.line_nr
            end
          end
          if lnptr.text =~ /^[#]/
            script = true
          end
        when 2
          unless header_start
            if not lnptr.text =~ /^(\/[\*]|[#])/
              lnptr.mark_error 1
            else
              header_start = lnptr.line_nr
              if lnptr.text =~ /^[#]/
                script = true
              end
            end
          else
            if lnptr.text =~ /[\*]\//
              lnptr.mark_error
            end
            if not lnptr.text.match(object.name)
              lnptr.mark_error
            end
          end
        when 3
          if header_start && header_start == 2
            # header on second line so file name should
            # be on the third
            if not lnptr.text.match(object.name)
              lnptr.mark_error
            end
          end
        else
          if header_start
            # for */
            if lnptr.text =~ /[\*]\//
              hdr_lns = 1 + lnptr.line_nr - header_start
              if hdr_lns < 6
                lnptr.mark_error
                lnptr.to_eof # stop
              end
            else
              unless !script
                # for scripts
                if not lnptr.text =~ /[#]/
                  hdr_lns = 1 + lnptr.line_nr - header_start
                  if hdr_lns < 6
                    lnptr.mark_error
                    lnptr.to_eof # stop
                  end
                end
              end
            end
          end # header_start
        end
      end
    end #def run
  end

  Fuzz.register_fzzr(TAOX11FileHeaderChecker.new)
end
