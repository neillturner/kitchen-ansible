# -*- encoding: utf-8 -*-
#
# Author:: Tomoyuki Sakurai
#
# Copyright (C) 2018 Tomoyuki Sakurai
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
#

module Kitchen
  module Provisioner
    module Ansible
      class Os
        class Freebsd < Os

          def install_command
            <<-INSTALL
            pkg install -y ansible
            INSTALL
          end

          def etc_ansible_path
            '/usr/local/etc/ansible'
          end
        end
      end
    end
  end
end
