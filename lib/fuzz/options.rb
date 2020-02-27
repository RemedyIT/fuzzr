#--------------------------------------------------------------------
# @file    options.rb
# @author  Martin Corino
#
# @brief   Options module for fuzz
#
# @copyright Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

require 'ostruct'
require 'yaml'
require 'fuzz/log'

module Fuzz

  FUZZRC = '.fuzzrc'
  FUZZRC_GLOBAL = File.expand_path(File.join(ENV['HOME'] || ENV['HOMEPATH'] || '~', FUZZRC))

  OPTIONS = OpenStruct.new

  class << OPTIONS

    include Fuzz::LogMethods

    def options
      self
    end

    class Config < OpenStruct

      include Fuzz::LogMethods

      def initialize(hash=nil)
        super
        @table = _merge(_defaults, @table)
      end

      def options
        Fuzz.options
      end

      def merge(from)
        _merge(@table, from)
        self
      end

      def load(rcpath)
        log(3, "Loading #{FUZZRC} from #{rcpath}")
        _cfg = YAML.load(IO.read(rcpath))
        log(4, "Read from #{rcpath}: [#{_cfg}]")
        # handle automatic env var expansion in fzzr_paths
        _cfg[:fzzr_paths] = (_cfg[:fzzr_paths] || []).collect do |p|
          log(5, "Examining fzzr_path [#{p}]")
          # for paths coming from rc files environment vars are immediately expanded and
          p.gsub!(/\$([^\s\/]+)/) { |m| ENV[$1] }
          log(6, "Expanded fzzr_path [#{p}]")
          # resulting relative paths converted to absolute paths
          if File.directory?(p)   # relative to working dir?
            p = File.expand_path(p)
          else                    # relative to rc location?
            _fp = File.expand_path(File.join(File.dirname(rcpath), p))
            log(4, "Ignoring invalid fuzzer search path #{p} configured in #{rcpath}") unless File.directory?(_fp)
            p = _fp
          end
          log(4, "Adding fuzzer search path: #{p}")
          p
        end
        merge(_cfg)
      end

      def save(rcpath)
        File.open(rcpath, 'w') {|f| f << YAML.dump(@table) }
      end

      protected

      def _defaults
        {
          :brix_paths => []
        }
      end

      def _merge(to, from)
        from.each_pair do |(k,v)|
          k = k.to_sym
          if to.has_key?(k)
            case to[k]
            when Array
              to[k].concat v
            when Hash
              to[k].merge!(v)
            when OpenStruct
              _merge(to[k].__send__(:table), v)
            else
              to[k] = v
            end
          else
            to[k] = v
          end
        end
        to
      end

    end

    protected

    def _defaults
      {
        :verbose => (ENV['FUZZ_VERBOSE'] || 1).to_i,
        :recurse => true,
        :apply_fix => false,
        :config => Config.new({
          :follow_symlink => true,
          :exts => [],
          :filenames => [],
          :excludes => [],
          :add_files => false,
          :fzzr_paths => [],
          :fzzr_opts => {},
          :fzzr_excludes => []
        })
      }
    end

    def _rc_paths
      @rc_paths ||= []
    end
    def _loaded_rc_paths
      @loaded_rc_paths ||= []
    end

    def _add_rcpath(path)
      if _loaded_rc_paths.include?(File.expand_path(path))
        log(3, "ignoring already loaded rc : #{path}")
      else
        log(3, "adding rc path : #{path}")
        _rc_paths << path
      end
      _rc_paths
    end

    public

    def reset
      @table.clear
      @table.merge!(_defaults)
      _rc_paths.clear
      _rc_paths << FUZZRC_GLOBAL
      _loaded_rc_paths.clear
      (ENV['FUZZRC'] || '').split(/:|;/).each do |p|
        _add_rcpath(p)
      end
    end

    def load_config
      # first collect config from known (standard and configured) locations
      _rc_paths.collect {|path| File.expand_path(path) }.each do |rcp|
        log(3, "Testing rc path #{rcp}")
        if File.readable?(rcp) && !_loaded_rc_paths.include?(rcp)
          _cfg = Config.new.load(rcp)
          self[:config].merge(_cfg)
          _loaded_rc_paths << rcp
        else
          log(3, "Ignoring #{File.readable?(rcp) ? 'already loaded' : 'inaccessible'} rc path #{rcp}")
        end
      end
      # now scan working path for any rc files unless specified otherwise
      unless self[:no_rc_scan]
        _cwd = File.expand_path(Dir.getwd)
        log(3, "scanning working path #{_cwd} for rc files")
        # first collect any rc files found
        _rcpaths = []
        begin
          _rcp = File.join(_cwd, FUZZRC)
          if File.readable?(_rcp) && !_loaded_rc_paths.include?(_rcp)
            _rcpaths << _rcp
          else
            log(3, "Ignoring #{File.readable?(_rcp) ? 'already loaded' : 'inaccessible'} rc path #{_rcp}")
          end
          break if /\A(.:(\\|\/)|\.|\/)\Z/ =~ _cwd
          _cwd = File.dirname(_cwd)
        end while true
        # now load them in reverse order
        _rcpaths.reverse.each do |_rcp|
          _cfg = Config.new.load(_rcp)
          self[:config].merge(_cfg)
          _loaded_rc_paths << _rcp
        end
      end
      # lastly merge config specified by user on commandline
      self[:config].merge(user_config)
    end

    def add_config(rcpath)
      log_fatal("inaccessible rc path specified : #{rcpath}") unless File.readable?(rcpath)
      _add_rcpath(rcpath)
    end

    def user_config
      @user_config ||= Config.new
    end

  end # OPTIONS class

  OPTIONS.reset # initialize

end # Fuzz
