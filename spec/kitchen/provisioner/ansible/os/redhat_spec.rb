# -*- encoding: utf-8 -*-
#
# Author:: Mike Mead (<hi@mikemead.me>)
#
# Copyright (C) 2017 Mike Mead
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
require 'kitchen/provisioner/ansible/os/redhat'

include Kitchen::Ansible::TestHelpers

describe Kitchen::Provisioner::Ansible::Os::Redhat do
  let (:redhat) { Kitchen::Provisioner::Ansible::Os.make('redhat', config) }
  describe 'install_command' do
    subject(:install_command) { redhat.install_command }

    context 'when no ansible version is specified in the config' do
      let (:config) { empty_config }

      it { is_expected.to match /yum -y install ansible / }
    end

    context 'when an ansible version (1.2.3) is specified in the config' do
      let (:config) { config_with(ansible_version: "1.2.3") }

      it { is_expected.to match /yum -y install ansible1.2-1.2.3 / }
    end

    context 'when an ansible version (latest) is specified in the config' do
      let (:config) { config_with(ansible_version: "latest") }

      it { is_expected.to match /yum -y install ansible / }
    end

    context 'when no ansible package name (ansible1) is specified in the config' do
      let (:config) { config_with(ansible_package_name: "ansible1") }

      it { is_expected.to match /yum -y install ansible1 / }
    end

    context 'when no ansible package name (ansible1) and version (1.2.3) is specified in the config' do
      let (:config) { config_with(ansible_package_name: "ansible1", ansible_version: "1.2.3") }

      it { is_expected.to match /yum -y install ansible1-1.2.3 / }
    end
  end
end
