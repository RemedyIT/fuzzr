# encoding: utf-8
# -------------------------------------------------------------------
# fuzz.rb - TAOX11 fuzz checker
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzz
  VERSION = '0.9.6' unless defined? VERSION
end

require 'fuzz/fuzz'
