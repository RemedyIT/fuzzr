# encoding: utf-8
# -------------------------------------------------------------------
# fuzz.rb - TAOX11 fuzz checker
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

require 'optparse'
require 'tempfile'
require 'fileutils'
require 'yaml'
require 'fuzz/log'
require 'fuzz/system'
require 'fuzz/options'
require 'fuzz/fzzr'
require 'fuzz/version'

module Fuzz

  def self.root_path
    f = File.expand_path(__FILE__)
    f = File.expand_path(File.readlink(f)) if File.symlink?(f)
    File.dirname(f)
  end

  FUZZ_ROOT = self.root_path

  class << self

    include LogMethods
    include Sys::SysMethods

    def reporter
      @reporter ||= Fuzz::Reporter.new
    end

    def set_reporter(rep)
      @reporter = rep
    end
    alias :reporter= :set_reporter

    def options
      Fuzz::OPTIONS
    end

    def reset
      options.reset
    end

    def load_config
      options.load_config
    end

    def includes
      unless @include_re
        @include_re = []
        # @include_re << "\\.(#{Fuzz::FileObject.extensions.join('|')})$"
        # @include_re << "#{Fuzz::FileObject.filenames.join('|')}$"
        @include_re << "\\.(#{options.config[:exts].join('|')})$"
        @include_re << "#{options.config[:filenames].join('|')}$"
      end
      @include_re
    end

    #
    # fuzzer registration
    #

    def fuzzers
      @fuzzers ||= {}
    end

    def register_fzzr(fzzr)
      raise RuntimeError, "Duplicate fuzzer registration: #{fzzr.fuzz_id}" if fuzzers.has_key?(fzzr.fuzz_id)
      fuzzers[fzzr.fuzz_id] = fzzr
      fzzr.setup(options.optparser) if options.optparser && fzzr.respond_to?(:setup) && fzzr_included?(fzzr)
    end

    def get_fzzr(id)
      fuzzers[id]
    end

    def fzzr_excluded?(fzzr)
      options.config[:fzzr_excludes].include?(fzzr.fuzz_id.to_sym)
    end

    def fzzr_included?(fzzr)
      !fzzr_excluded?(fzzr)
    end

    #
    # load fuzzers
    #
    def load_fuzzers
      # standard fuzzers included in Gem
      unless loaded_fzzr_paths.include?(_p = File.join(FUZZ_ROOT, 'fuzzers'))
        Dir.glob(File.join(_p, '*.rb')).each do |fnm|
          require fnm
        end
        loaded_fzzr_paths << _p
      end
      # configured fuzzers
      options.config[:fzzr_paths].each do |fzzrpath|
        unless loaded_fzzr_paths.include?(_p = File.expand_path(fzzrpath))
          Dir.glob(File.join(_p, '*.rb')).each do |fnm|
            require fnm
          end
          loaded_fzzr_paths << _p
        end
      end
    end

    private

    def loaded_fzzr_paths
      @loaded_fuzzr_paths ||= []
    end

  end

  ## Backwards compatibility
  def self.log_verbose(msg)
    log_info(msg) if verbose?
  end

  #
  # Option methods
  #

  def self.verbosity
    options.verbose
  end

  def self.apply_fix?
    options.apply_fix || false
  end

  def self.follow_symlink?
    options.config[:follow_symlink] || false
  end

  def self.excludes
    options.config[:excludes] || []
  end

  def self.excluded?(object)
    excludes.any? { |excl| (object.fullpath =~ /#{excl}/) }
  end

  #
  # parse commandline arguments
  #
  def self.init_optparser
    script_name = File.basename($0)
    if not script_name =~ /fuzz/
      script_name = "ruby "+$0
    end

    options.optparser = opts = OptionParser.new
    opts.banner = "Usage: #{script_name} [options] [glob [glob]]\n\n"
    opts.separator "\n--- [General options] ---\n\n"
    opts.on('-t', '--filetype', '=EXT', String,
            'Defines an alternative filetype to search and scan. Can be specified multiple times.',
            "Default: #{Fuzz::FileObject.extensions.join('|')}") { |v|
              (options.user_config[:exts] ||= []) << v
            }
    opts.on('-f', '--file', '=NAME', String,
            'Defines an alternative filename to search and scan. Can be specified multiple times.',
            "Default: #{Fuzz::FileObject.filenames.join('|')}") { |v|
              (options.user_config[:filenames] ||= []) << v
            }
    opts.on('-a', '--add-files',
            'Add custom filenames and/or filetype extensions to default list instead of replacing defaults.',
            'Default: false') { |v|
              options.user_config[:add_files] = true
            }
    opts.on('-S', '--no-symlinks',
            'Do not follow symlinks.',
            'Default: follow symlinks') { |v|
              options.user_config[:follow_symlink] = false
            }
    opts.on('-P', '--fzzr-path', '=PATH',
            'Adds search path for Fuzzers.',
            "Default: loaded from ~/#{FUZZRC} and/or ./#{FUZZRC}") { |v|
              (options.user_config[:fzzr_paths] ||= []) << v.to_s
            }
    opts.on('-B', '--blacklist', '=FZZRID',
            'Adds Fuzzer ID to list of fuzzers to exclude from Fuzz check.',
            'Default: none') { |v|
              (options.user_config[:fzzr_excludes] ||= []) << v.to_sym
            }
    opts.on('-X', '--exclude', '=MASK',
            'Adds path mask (regular expression) to list to exclude from Fuzz check.',
            'Default: none') { |v|
              (options.user_config[:excludes] ||= []) << v
            }
    opts.on('-c', '--config', '=FUZZRC',
            'Load config from FUZZRC file.',
            "Default:  ~/#{FUZZRC} and/or ./#{FUZZRC}") { |v|
      options.add_config(v)
    }
    opts.on('--write-config', '=[FUZZRC]',
            'Write config to file and exit.',
            "Default: ./#{FUZZRC}") { |v|
      options.user_config.save(String === v ? v : FUZZRC)
      exit
    }
    opts.on('--show-config',
            'Display config settings and exit.') { |v|
      options.load_config
      puts YAML.dump(options.config.__send__ :table)
      exit
    }

    opts.separator ''
    opts.on('-o', '--output', '=FILE', String,
            'Specifies filename to write Fuzz messages to.',
            'Default: stderr') { |v|
              options.output = v
            }
    opts.on('-p', '--apply-fix',
            'Apply fixes (if any) for Fuzz errors.',
            'Default: false') { |v|
              options.apply_fix = true
            }
    opts.on('-n', '--no-recurse',
            'Prevents directory recursion in file selection.',
            'Default: recurse') { |v|
              options.recurse = false
            }
    opts.on('-v', '--verbose',
            'Run with increased verbosity level. Repeat to increase more.',
            'Default: 1') { |v| options.verbose += 1 }

    opts.separator ''
    opts.on('-L', '--list',
            'List available Fuzzers and exit.') {
      options.load_config
      load_fuzzers
      puts "TAOX11 fuzz checker #{FUZZ_VERSION_MAJOR}.#{FUZZ_VERSION_MINOR}.#{FUZZ_VERSION_RELEASE}"
      puts FUZZ_COPYRIGHT
      puts('%-30s %s' % %w{Fuzzer Description})
      puts(('-' * 30)+' '+('-' * 48))
      fuzzers.values.each { |fzzr| puts('%-30s %s' % [fzzr.fuzz_id, fzzr.description]) }
      puts
      exit
    }

    opts.separator ""
    opts.on('-V', '--version',
            'Show version information and exit.') {
      puts "TAOX11 fuzz checker #{FUZZ_VERSION_MAJOR}.#{FUZZ_VERSION_MINOR}.#{FUZZ_VERSION_RELEASE}"
      puts FUZZ_COPYRIGHT
      exit
    }
    opts.on('-h', '--help',
            'Show this help message.') {
      options.load_config
      load_fuzzers
      puts opts;
      puts;
      exit
    }

    opts.separator "\n--- [Fuzzer options] ---\n\n"
  end

  def self.parse_args(argv)
    options.optparser.parse!(argv)
  end

  def self.select_fzzrs(object)
    fuzzers.values.collect { |fzzr| (fzzr_included?(fzzr) && fzzr.applies_to?(object)) ? fzzr : nil }.compact
  end

  def self.update_file_object(fo)
    if File.writable?(fo.fullpath)
      log_verbose(%Q{Updating #{fo}...})
      ftmp = Tempfile.new(fo.name)
      log_verbose(%Q{+ Writing temp file #{ftmp.path}...})
      fo.lines.each { |ln| ftmp.print ln }
      ftmp.close(false) # close but do NOT unlink
      log_verbose(%Q{+ Replacing #{fo} with #{ftmp.path}})
      # create temporary backup
      ftmp2 = Tempfile.new(fo.name)
      ftmp2_name = ftmp2.path.dup
      ftmp2.close(true)
      mv(fo.fullpath, ftmp2_name)
      # replace original
      begin
        mv(ftmp.path, fo.fullpath)
        # preserve file mode
        chmod(File.lstat(ftmp2_name).mode, fo.fullpath)
      rescue
        log_error(%Q{FAILED updating #{fo}: #{$!}})
        # restore backup
        mv(ftmp2_name, fo.fullpath)
        raise
      end
      # remove backup
      File.unlink(ftmp2_name)
      log_verbose(%Q{Finished updating #{fo}.})
      return true
    else
      log_error(%Q{NO_ACCESS - cannot update #{fo}})
      return false
    end
  end

  def self.handle_object(object)
    log_verbose(%Q{Handling #{object}})
    fzzrs = select_fzzrs(object)
    no_fixes_allowed = false
    rc = fzzrs.inject(true) do |result, fzzr|
      log_verbose(%Q{+ Running fuzzer #{fzzr.fuzz_id}})
      begin
        if fzzr.run(object, options.apply_fix)
          result
        else
          log_verbose(%Q{+ Error from fuzzer #{fzzr.fuzz_id}})
          false
        end
      rescue
        log_error(%Q{EXCEPTION CAUGHT running fuzzer #{fzzr.fuzz_id} on #{object} - #{$!}\n#{$!.backtrace.join("\n")}})
        no_fixes_allowed = true
        break ## immediately stop handling this object, rc will remain false
      end
    end
    unless no_fixes_allowed
      if Fuzz.apply_fix? && object.changed?
        rc = update_file_object(object) && rc
      end
    end
    rc ? true : false
  end

  def self.iterate_paths(paths)
    paths.inject(true) do |result, path|
      if File.readable?(path) && (!File.symlink?(path) || follow_symlink?)
        if File.directory?(path)
          rc = handle_object(dirobj = Fuzz::DirObject.new(path))
          log_verbose(%Q{Iterating #{path}})
          if options.recurse && !excluded?(dirobj)
            rc = iterate_paths(Dir.glob(File.join(path, '*'))) && rc
          end
          rc
        elsif File.file?(path)
          handle_object(Fuzz::FileObject.new(path))
        else
          true
        end
      else
        log_warning(File.readable?(path) ? %Q{Cannot read #{path}} : %Q{Cannot follow symlink #{}path})
        false
      end && result
    end
  end

  def self.run_fzzrs(argv)
    options.config[:exts].concat(Fuzz::FileObject.extensions) if options.config[:exts].empty? || options.config[:add_files]
    options.config[:filenames].concat(Fuzz::FileObject.filenames) if options.config[:filenames].empty? || options.config[:add_files]

    options.config[:exts].uniq!
    options.config[:filenames].uniq!

    f_close_output = false
    if String === options.output
      options.output = File.open(options.output, 'w')
      f_close_output = true
    end
    begin
      # determin files/paths to test
      paths = argv.collect { |a| Dir.glob(a) }.flatten.uniq
      paths = Dir.glob('*') if paths.empty?
      # scan all determined objects
      return iterate_paths(paths)
    ensure
      options.output.close if f_close_output
    end
  end

  def self.run
    init_optparser

    # parse arguments
    parse_args(ARGV)

    # load config (if any)
    options.load_config

    # load fuzzers
    load_fuzzers

    run_fzzrs(ARGV)
  end

end
