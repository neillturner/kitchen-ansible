# -*- encoding: utf-8 -*-
#
# Author:: James Cuzella (<james.cuzella@lyraphase.com>)
#
# Copyright (C) 2014, James Cuzella
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Add lib dir to Ruby's LOAD_PATH so we can easily require things in there
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'pry'
require 'rspec'

RSpec.configure do |config|
  config.tty = true
  config.color = true
end

module Kitchen module Ansible module TestHelpers
  def config_with(values = {})
    Kitchen::Provisioner::Ansible::Config.new({
      sudo: true,
      sudo_command: 'sudo'
    }.merge!(values))
  end

  alias_method :empty_config, :config_with

end end end
