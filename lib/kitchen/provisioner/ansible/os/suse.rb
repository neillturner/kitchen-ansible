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
#

module Kitchen
  module Provisioner
    module Ansible
      class Os
        class Suse < Os
          def install_command
            <<-INSTALL
            if [ ! $(which ansible) ]; then
              #{sudo_env('zypper')} ar #{@config[:python_sles_repo]}
              #{sudo_env('zypper')} ar #{@config[:ansible_sles_repo]}
              #{update_packages_command}
              #{sudo_env('zypper')} --non-interactive install ansible
            fi
            INSTALL
          end

          def update_packages_command
            @config[:update_package_repos] ? "#{sudo_env('zypper')} --gpg-auto-import-keys ref" : nil
          end
        end
      end
    end
  end
end
