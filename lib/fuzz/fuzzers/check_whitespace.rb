# encoding: utf-8
# -------------------------------------------------------------------
# check_whitespace.rb - TAOX11 whitespace checker
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzzers
  class WhitespaceChecker
    include Fuzz::Fzzr
    def initialize
      @fuzz_id = :check_whitespace
      @description = 'checks for trailing whitespace, incorrect line endings and tabs'
    end

    def setup(optparser)
      optparser.on('--wsc:tab-spacing=NUM', Integer,
                   'Fuzzers::WhitespaceChecker - defines tab spacing to use for TAB replacement when --apply-fix is enabled.',
                   "Default: #{tab_spacing}") {|v| self.options[:tabspacing] = v }
    end

    def applies_to?(object)
      Fuzz::FileObject === object && !is_excluded?(object)
    end

    def run(object, apply_fix)
      _tws = []
      _tabs = []
      object.iterate(fuzz_id) do |lnptr|
        if lnptr.text =~ /(\s\n|[\ \t\f\r\x0B])\Z/
          if apply_fix
            Fuzz.log_verbose(%Q{#{object.path}:#{lnptr.line_nr} - stripping trailing whitespace})
            lnptr.text.rstrip!
            lnptr.text << "\n" if $1.end_with?("\n")
          else
            _tws << lnptr.line_nr
          end
        end
        if lnptr.text =~ /\t/
          if apply_fix
            Fuzz.log_warning(%Q{#{object.path}:#{lnptr.line_nr} - replacing tabs})
            lnptr.text.gsub!(/\t/, ' ' * tab_spacing)
          else
            _tabs << lnptr.line_nr
          end
        end
      end
      Fuzz.log_error(%Q{#{object.path}:[#{_tws.join(',')}] trailing whitespace or incorrect line ending detected}) unless _tws.empty?
      Fuzz.log_error(%Q{#{object.path}:[#{_tabs.join(',')}] tab(s) detected}) unless _tabs.empty?
      return (_tws.empty? && _tabs.empty?)
    end

  private
    def tab_spacing
      self.options[:tabspacing] || 2
    end
  end

  Fuzz.register_fzzr(WhitespaceChecker.new)
end
