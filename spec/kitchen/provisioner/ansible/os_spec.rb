# -*- encoding: utf-8 -*-
#
# Author:: Michael Heap (<m@michaelheap.com>)
#
# Copyright (C) 2015 Michael Heap
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

require 'spec_helper'

require 'kitchen/provisioner/ansible/os'

include Kitchen::Ansible::TestHelpers

# Work around for lazy loading
describe Kitchen::Provisioner::Ansible::Os do
  describe 'make new instance' do
    it 'returns nil for an unknown os' do
      c = Kitchen::Provisioner::Ansible::Os.make('dinosaurs', [])
      expect(c).to equal nil
    end

    [
      ['debian', Kitchen::Provisioner::Ansible::Os::Debian],
      ['ubuntu', Kitchen::Provisioner::Ansible::Os::Debian],
      ['redhat', Kitchen::Provisioner::Ansible::Os::Redhat],
      ['centos', Kitchen::Provisioner::Ansible::Os::Redhat],
      ['fedora', Kitchen::Provisioner::Ansible::Os::Fedora],
      ['amazon', Kitchen::Provisioner::Ansible::Os::Amazon],
      ['suse', Kitchen::Provisioner::Ansible::Os::Suse],
      ['alpine', Kitchen::Provisioner::Ansible::Os::Alpine],
      ['openbsd', Kitchen::Provisioner::Ansible::Os::Openbsd],
      ['freebsd', Kitchen::Provisioner::Ansible::Os::Freebsd]
    ].each do |item|
      it "return the correct class for '#{item[0]}'" do
        c = Kitchen::Provisioner::Ansible::Os.make(item[0], [])
        expect(c).to be_an_instance_of item[1]
      end
    end
  end

  describe 'sudo_env' do
    it 'returns just sudo with no additional config' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', empty_config)
      expect(c.sudo_env('ls')).to eq('sudo ls')
    end

    it 'can be provided with a https_proxy' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', config_with(https_proxy: 'https://localhost:1234'))
      expect(c.sudo_env('ls')).to eq('sudo env  https_proxy=https://localhost:1234  ls')
    end

    it 'can be provided with a http_proxy' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', config_with(http_proxy: 'http://localhost:5678'))
      expect(c.sudo_env('ls')).to eq('sudo env http_proxy=http://localhost:5678   ls')
    end

    it 'can be provided with no_proxy only and does not populate' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', config_with(no_proxy: 'http://localhost:9999'))
      expect(c.sudo_env('ls')).to eq('sudo ls')
    end

    it 'can be provided with no_proxy and http_proxy and does populate both' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', config_with(http_proxy: 'http://localhost:5678',
                                                                  no_proxy: 'http://localhost:9999'))
      expect(c.sudo_env('ls')).to eq('sudo env http_proxy=http://localhost:5678  no_proxy=http://localhost:9999 ls')
    end

    it 'can be provided with all proxy options' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', config_with(https_proxy: 'https://localhost:1234',
                                                                  http_proxy: 'http://localhost:5678',
                                                                  no_proxy: 'http://localhost:9999'))
      expect(c.sudo_env('ls')).to eq('sudo env http_proxy=http://localhost:5678 https_proxy=https://localhost:1234 no_proxy=http://localhost:9999 ls')
    end
  end

  describe 'etc_ansible_path' do
    it 'returns /etc/ansible' do
      c = Kitchen::Provisioner::Ansible::Os.new('testing', empty_config)
      expect(c.etc_ansible_path).to eq '/etc/ansible'
    end

    context 'when OS is FreeBSD' do
      it 'returns /use/local/etc/ansible' do
        c = Kitchen::Provisioner::Ansible::Os.make('freebsd', empty_config)
        expect(c.etc_ansible_path).to eq '/usr/local/etc/ansible'
      end
    end
  end
end
