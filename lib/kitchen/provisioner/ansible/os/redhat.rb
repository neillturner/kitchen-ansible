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
            #{redhat_yum_repo}
            #{update_packages_command}
            EL_RELEASE=$(rpm -E %{rhel})

            if [ "${EL_RELEASE}" -lt 8 ]; then
              #{sudo_env('yum')} -y install #{ansible_package_name} libselinux-python git
            else
              #{sudo_env('yum')} -y install #{ansible_package_name} python3-libselinux git
            fi
            fi
            INSTALL
          end

          def update_packages_command
            @config[:update_package_repos] ? "#{sudo_env('yum')} makecache" : nil
          end

          def install_epel_repo
            @config[:enable_yum_epel] ? sudo_env('yum install epel-release -y') : nil
          end

          def ansible_package_version_suffix
            return unless @config[:ansible_version] && @config[:ansible_version] != 'latest'

            if @config[:ansible_package_name]
              "-#{@config[:ansible_version]}"
            else
              "#{@config[:ansible_version][0..2]}-#{@config[:ansible_version]}"
            end
          end

          def ansible_package_name
            if @config[:ansible_package_name]
              "#{@config[:ansible_package_name]}#{ansible_package_version_suffix}"
            else
              "ansible#{ansible_package_version_suffix}"
            end
          end

          def redhat_yum_repo
            if @config[:ansible_yum_repo]
              <<-INSTALL
              #{sudo_env('rpm')} -ivh #{@config[:ansible_yum_repo]}
              INSTALL
            else
              <<-INSTALL
              if ! yum repolist epel | grep -q epel; then
                #{sudo_env('rpm')} -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-`rpm -E %dist | sed -n 's/.*el\\([0-9]\\).*/\\1/p'`.noarch.rpm
              fi
              INSTALL
            end
          end
        end
      end
    end
  end
end
