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
        class Redhat < Os

          def install_command
            <<-INSTALL
            if [ ! $(which ansible) ]; then
            #{install_epel_repo}
            #{sudo_env('rpm')} -ivh #{@config[:ansible_yum_repo]}
            #{update_packages_command}
            #{sudo_env('yum')} -y install ansible#{ansible_redhat_version} libselinux-python git
            fi
            INSTALL
          end

          def update_packages_command
            @config[:update_package_repos] ? "#{sudo_env('yum')} makecache" : nil
          end

          def install_epel_repo
            @config[:enable_yum_epel] ? sudo_env('yum install epel-release -y') : nil
          end

          def ansible_redhat_version
            @config[:ansible_version] ? "-#{@config[:ansible_version]}" : nil
          end


        end
      end
    end
  end
end

