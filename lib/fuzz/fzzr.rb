# encoding: utf-8
# -------------------------------------------------------------------
# fuzzr.rb - TAOX11 Fuzzer bases
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzz
  ##
  # Fuzzers are objects having the following readonly attributes:
  #   #fuzz_id    : id of fuzzer (Symbol)
  #   #description: (String)
  #   #errormsg   : (String)
  #
  # and having the following methods:
  #   #applies_to?(object)  : checks if the test applies to the object passed
  #                           (Fuzz::DirObject or Fuzz::FileObject)
  #   #run(object,apply_fix): runs the fzzr test on the object passed
  #                           (Fuzz::DirObject or Fuzz::FileObject)
  #                           when apply_fix == true Fuzzer is directed to
  #                           attempt to fix any problems found (future)
  #
  # Fuzz::Fzzr is provided as a convenience Mixin for fuzzers
  #
  # Fuzzers can inspect the options passed to fuzz.rb by referencing Fuzz::OPTIONS
  ##

  module Fzzr
    attr_reader :fuzz_id, :description, :errormsg

    def applies_to?(object)
      !is_excluded?(object)
    end

    def setup(optparser)
    end

    def run(object, apply_fix)
      true
    end

    def is_excluded?(object)
      # force excludes to be parsed
      _excludes
      # now examine
      ((!_is_included?(object)) || _excludes.any? { |excl| (object.fullpath =~ /#{excl}/) })
    end

    def options
      Fuzz::OPTIONS[:config][:fzzr_opts][self.fuzz_id] ||= {}
    end

    private

    def _is_included?(object)
      Fuzz::DirObject === object || _includes.empty? || _includes.any? { |incl| (object.fullpath =~ /#{incl}/) }
    end

    def _includes
      @_includes ||= Fuzz.includes.dup
    end

    def _excludes
      unless @_excludes
        @_excludes = []
        @_excludes.concat(Fuzz.excludes)
        Fuzz::OPTIONS[:config][:fzzr_paths].each do |fzzrpath|
          fzzr_excl_file = File.join(fzzrpath, "#{self.fuzz_id}.excludes")
          if File.readable?(fzzr_excl_file)
            lns = IO.readlines(fzzr_excl_file).collect { |l| l.strip }
            @_excludes.concat(lns.select {|l| !(l.empty? || l[0] == '!') })
            _includes.concat(lns.select {|l| !(l.empty? || l[0] != '!') }.collect {|l| l[1,l.size].strip })
          else
            false
          end
        end
      end
      @_excludes
    end
  end # Fzzr

  class DirObject
    attr_reader :path, :fullpath, :name, :ext
    def initialize(path)
      @path = path
      @fullpath = File.expand_path(path)
      @name = File.basename(path)
      @ext = File.extname(path).sub(/^\./,'')
    end

    def changed?
      false
    end

    def iterate(fzzr_id, &block)
      # nothing to iterate over
      true
    end

    def to_s
      "Dir:#{path}"
    end
  end # DirObject

  class FileObject
    EXTS = [
      'h', 'hxx', 'hpp', 'c', 'cc', 'cxx', 'cpp', 'H', 'C', 'inl', 'asm',
      'rb', 'erb', 'pl', 'pm', 'py',
      'idl', 'pidl',
      'mwc', 'mpc', 'mpb', 'mpt', 'mpd',
      'cdp', 'xml', 'conf', 'html',
      'asc', 'adoc'
      ]
    FILES = [
      'ChangeLog', 'README'
      ]

    def self.extensions
      EXTS
    end

    def self.filenames
      FILES
    end

    class LinePointer
      attr_reader :err_lines

      FZZR_ENABLE_RE = /X11_FUZZ\: enable ([^\s]+)/
      FZZR_DISABLE_RE = /X11_FUZZ\: disable ([^\s]+)/

      def initialize(lines, fzzr_id)
        @lines = lines
        @fzzr_id = fzzr_id.to_s
        @err_lines = []
        reset
      end
      def fzzr_disabled?
        @fzzr_disabled
      end
      def line_nr
        @line_nr+1
      end
      def text_at(offs)
        ln = @line_nr+offs
        if ln>=0 && ln<@lines.size
          return @lines[ln]
        end
        nil
      end
      def set_text_at(offs, txt)
        ln = @line_nr+offs
        if ln>=0 && ln<@lines.size
          return (@lines[ln] = txt)
        end
        nil
      end
      def text
        text_at(0)
      end
      def text=(txt)
        set_text_at(0, txt)
      end
      def move(offs)
        if offs < 0
          _backward(-offs) unless bof?
        else
          _forward(offs) unless eof?
        end
        self.line_nr
      end
      def reset
        @line_nr = 0
        @fzzr_disabled = false
        _check_fzzr_escape
      end
      def to_eof
        _forward(@lines.size - @line_nr)
      end
      def eof?
        @line_nr >= @lines.size
      end
      def bof?
        @line_nr <= 0
      end
      def mark_error(ln = nil)
        @err_lines << (ln || (@line_nr+1))
      end

      private

      def _forward(distance)
        distance.times do
          @line_nr += 1
          break if eof?
          _check_fzzr_escape
        end
      end

      def _backward(distance)
        distance.times do
          break if bof?
          @line_nr -= 1
          _check_fzzr_escape(false)
        end
      end

      def _check_fzzr_escape(forward = true)
        begin
          if FZZR_ENABLE_RE =~ @lines[@line_nr]
            @fzzr_disabled = !forward if $1 == @fzzr_id
          elsif FZZR_DISABLE_RE =~ @lines[@line_nr]
            @fzzr_disabled = forward if $1 == @fzzr_id
          end
        rescue
          Fuzz.log_error(%Q{ERROR: Exception while checking fzzr escapes in line #{@line_nr+1} - #{$!}\n#{@lines[@line_nr]}})
          raise
        end
      end
    end # LinePointer

    attr_reader :path, :fullpath, :name, :ext, :lines

    def initialize(path)
      @path = path
      @fullpath = File.expand_path(path)
      @name = File.basename(path)
      @ext = File.extname(path).sub(/^\./,'')
      @lines = nil
      @pointer = nil
      @changed = false
    end

    def changed?
      @changed
    end

    def iterate(fzzr_id, &block)
      @lines ||= IO.readlines(fullpath)
      lines_copy = @lines.collect {|l| l.dup }
      pointer = LinePointer.new(@lines, fzzr_id)
      begin
        block.call(pointer) unless pointer.fzzr_disabled?
        pointer.move(1)
      end while !pointer.eof?
      Fuzz.log_error(%Q{#{self.path}[#{pointer.err_lines.join(',')}] #{Fuzz.get_fzzr(fzzr_id).errormsg}}) unless pointer.err_lines.empty?
      @changed |= (@lines != lines_copy)
      lines_copy = nil
      return pointer.err_lines.empty?
    end

    def to_s
      "File:#{fullpath}"
    end
  end # FileObject
end # Fuzz
