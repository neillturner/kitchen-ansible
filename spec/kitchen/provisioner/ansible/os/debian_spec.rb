# -*- encoding: utf-8 -*-
#
# Author:: Greg Symons (<gsymons@gsconsulting.biz>)
#
# Copyright (C) 2015 Greg Symons
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

require 'kitchen/provisioner/ansible/os'
require 'kitchen/provisioner/ansible/os/debian'

include Kitchen::Ansible::TestHelpers

describe Kitchen::Provisioner::Ansible::Os::Debian do
  let (:debian) { Kitchen::Provisioner::Ansible::Os.make('debian', config) }
  describe 'install_command' do
    subject(:install_command) { debian.install_command }
    
    context 'when no ansible version is specified in the config' do
      let (:config) { empty_config }

      it { is_expected.to match /apt-get -y install ansible\s*$/m }
    end

    context 'when an ansible version is specified in the config' do
      let (:config) { config_with(ansible_version: "1.2.3") }
   
      it { is_expected.to match /apt-get -y install ansible=1.2.3/ }
    end
  end
end
