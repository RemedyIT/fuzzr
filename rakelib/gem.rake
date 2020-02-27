#--------------------------------------------------------------------
# gem.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the fuzzr LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------
require 'rubygems'
begin
  require 'rubygems/builder'
rescue LoadError
  require 'rubygems/package'
end

require './lib/fuzz/version'

module Fuzz

  def self.pkg_root
    File.dirname(File.expand_path(File.dirname(__FILE__)))
  end

  def self.define_spec(name, version, &block)
    gemspec = Gem::Specification.new(name,version)
    gemspec.required_rubygems_version = Gem::Requirement.new(">= 0") if gemspec.respond_to? :required_rubygems_version=
    block.call(gemspec)
    gemspec
  end

  def self.build_gem(gemspec)
    if defined?(Gem::Builder)
      gem_file_name = Gem::Builder.new(gemspec).build
    else
      gem_file_name = Gem::Package.build(gemspec)
    end

    pkg_dir = File.join(pkg_root, 'pkg')
    FileUtils.mkdir_p(pkg_dir)

    gem_file_name = File.join(pkg_root, gem_file_name)
    FileUtils.mv(gem_file_name, pkg_dir)
  end
end

desc 'Build fuzzr gem'
task :gem do
  gemspec = Fuzz.define_spec('fuzzr', Fuzz::FUZZ_VERSION) do |gem|
    # gem is a Gem::Specification... see https://guides.rubygems.org/specification-reference/ for more options
    gem.summary = %Q{fuzzr}
    gem.description = %Q{Fuzzer}
    gem.email = 'mcorino@remedy.nl'
    gem.homepage = "https://github.com/RemedyIT/fuzzr"
    gem.authors = ['Martin Corino', 'Johnny Willemsen']
    gem.files = %w{LICENSE README.rdoc}.concat(Dir.glob('{lib,fuzzers}/**/*'))
    gem.extensions = []
    gem.extra_rdoc_files = %w{LICENSE README.rdoc}
    gem.rdoc_options << '--main' << 'README.rdoc'
    gem.executables = %w{fuzz}
    gem.license = 'MIT'
    gem.metadata = {
      "bug_tracker_uri"   => "https://github.com/RemedyIT/fuzzr/issues",
      "source_code_uri"   => "https://github.com/RemedyIT/fuzzr"
    }
    gem.required_ruby_version = '>= 2.0'
  end
  Fuzz.build_gem(gemspec)
end
