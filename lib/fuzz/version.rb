# encoding: utf-8
# -------------------------------------------------------------------
# version.rb - TAOX11 fuzz checker
#
# Author: Martin Corino
#
# Copyright (c) Remedy IT Expertise BV
# -------------------------------------------------------------------

module Fuzz

  FUZZ_VERSION_MAJOR = 0
  FUZZ_VERSION_MINOR = 9
  FUZZ_VERSION_RELEASE = 9
  FUZZ_VERSION = "#{FUZZ_VERSION_MAJOR}.#{FUZZ_VERSION_MINOR}.#{FUZZ_VERSION_RELEASE}"
  FUZZ_COPYRIGHT = "Copyright (c) 2012-#{Time.now.year} Remedy IT Expertise BV, The Netherlands".freeze

end
