# -*- encoding: utf-8 -*-
#
# Author:: Michael Heap (<m@michaelheap.com>)
#          Mark McKinstry
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
        class Fedora < Os
          def install_command
            <<-INSTALL

            if [ ! $(which ansible) ]; then
            #{redhat_yum_repo}
            #{update_packages_command}
            #{sudo_env('dnf')} -y install #{ansible_package_name} libselinux-python git python2-dnf
            fi
            INSTALL
          end

          def update_packages_command
            @config[:update_package_repos] ? "#{sudo_env('dnf')} makecache" : nil
          end

          def ansible_package_name
            if @config[:ansible_version] == 'latest' || @config[:ansible_version] == nil
              "ansible"
            else
              "ansible#{@config[:ansible_version][0..2]}-#{@config[:ansible_version]}"
            end
          end

          def redhat_yum_repo
            if @config[:ansible_yum_repo]
              <<-INSTALL
              #{sudo_env('rpm')} -ivh #{@config[:ansible_yum_repo]}
              INSTALL
            end
          end
        end
      end
    end
  end
end
