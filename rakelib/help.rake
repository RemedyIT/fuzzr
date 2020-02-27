#--------------------------------------------------------------------
# help.rake - build file
#
# Author: Martin Corino
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the fuzzr LICENSE which is
# included with this program.
#
# Copyright (c) Remedy IT Expertise BV
#--------------------------------------------------------------------

module Fuzz
  HELP = <<__HELP_TXT

fuzzr Rake based build system
-------------------------------

commands:

rake [rake-options] help             # Provide help description about fuzzr build system
rake [rake-options] gem              # Build fuzzr gem

__HELP_TXT
end

namespace :fuzz do
  task :help do
    puts Fuzz::HELP
  end
end

desc 'Provide help description about fuzzr build system'
task :help => 'fuzz:help'
