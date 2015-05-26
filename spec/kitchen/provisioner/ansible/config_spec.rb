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

require 'kitchen'
require 'kitchen/provisioner/ansible/config'

# Work around for lazy loading
describe Kitchen::Provisioner::Ansible::Config do

  describe "default values" do

    [
      [:ansible_verbose, false],
      [:require_ansible_omnibus, false],
      [:ansible_omnibus_url, nil],
      [:ansible_omnibus_remote_path, '/opt/ansible'],
      [:ansible_version, nil],
      [:require_ansible_repo, true],
      [:extra_vars, {}],
      [:tags, []],
      [:ansible_apt_repo, "ppa:ansible/ansible"],
      [:ansible_yum_repo, "https://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"],
      [:chef_bootstrap_url, "https://www.getchef.com/chef/install.sh"],
      [:requirements_path, false],
      [:ansible_verbose, false],
      [:ansible_verbosity, 1],
      [:ansible_check, false],
      [:ansible_diff, false],
      [:ansible_platform, ''],
      [:update_package_repos, true]
    ].each do |item|
      it "should contain the correct default value for '#{item[0]}'" do
      c = Kitchen::Provisioner::Ansible::Config.new({})
        expect(c[item[0]]).to eq item[1]
      end
    end
  end

  describe "set values" do

    [
      [:ansible_verbose, 4],
      [:require_ansible_omnibus, true],
      [:ansible_omnibus_url, 'http://example.com'],
      [:ansible_omnibus_remote_path, '/tmp/foo'],
      [:ansible_version, '1.9.2'],
      [:require_ansible_repo, false],
      [:extra_vars, {:foo => "bar"}],
      [:tags, ["one", "two"]],
      [:ansible_apt_repo, "ppa:demo/ansible"],
      [:ansible_yum_repo, "https://example.com/ansible.rpm"],
      [:chef_bootstrap_url, "https://www.example.com/install_chef.sh"],
      [:requirements_path, "/path/to/req"],
      [:ansible_verbose, true],
      [:ansible_verbosity, 8],
      [:ansible_check, true],
      [:ansible_diff, true],
      [:ansible_platform, 'banana'],
      [:update_package_repos, false]
    ].each do |item|
      it "should contain the correct set value for '#{item[0]}'" do
      c = Kitchen::Provisioner::Ansible::Config.new({item[0] => item[1]})
        expect(c[item[0]]).to eq item[1]
      end
    end
  end
end
