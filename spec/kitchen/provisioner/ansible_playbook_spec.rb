# -*- encoding: utf-8 -*-
#
# Author:: Neill Turner (<neillwturner@gmail.com>)
#
# Copyright (C) 2013,2014 Neill Turner
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

require_relative '../../spec_helper'
require 'kitchen'

# Work around for lazy loading
require 'kitchen/provisioner/ansible_playbook'

describe Kitchen::Provisioner::AnsiblePlaybook do
  let(:provisioner) do
    Kitchen::Provisioner.for_plugin("ansible_playbook", config)
  end

  let(:config) do
    {}
  end

  it "should give a sane run_command" do
    expect(provisioner.run_command).to match(/ansible-playbook/)
  end

  it "should not be verbose by default" do
    expect(provisioner[:ansible_verbose]).to eq false
    expect(provisioner.send(:ansible_verbose_flag)).to be_nil
  end

  it "should be configured to be verbose when ansible_verbose is set" do
    config[:ansible_verbose] = true
    expect(provisioner[:ansible_verbose]).to eq true
  end

  it "should generate the flag for 4 verbosity levels" do
    config[:ansible_verbose] = true
    (1..4).each do |i|
      config[:ansible_verbosity] = i
      # puts "Setting ansible_verbosity to: #{config[:ansible_verbosity]}"
      # puts "ansible_verbose_flag is: #{provisioner.send(:ansible_verbose_flag)}"
      expect( provisioner.send(:ansible_verbose_flag).count('v') ).to eq i
    end
  end

  it "should understand log level names and convert to a number of -v flags" do
    config[:ansible_verbose] = true
    { :info => 1, :warn => 2, :debug => 3, :trace => 4, 'info' => 1, 'warn' => 2, 'debug' => 3, 'trace' => 4 }.each do |log_level, i|
      # puts "Setting ansible_verbosity to: #{log_level} which converts to integer: #{i}"
      config[:ansible_verbosity] = log_level
      expect( provisioner.send(:ansible_verbose_flag).count('v') ).to eq i
    end
  end

  it "should raise an error if invalid verbosity level is given" do
    config[:ansible_verbose] = true
    config[:ansible_verbosity] = 1e10
    expect{ provisioner.send(:ansible_verbose_flag) }.to raise_error
  end
end
