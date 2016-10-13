# -*- encoding: utf-8 -*-
#
# Author:: Martin Etmajer (<martin@etmajer.com>)
#
# Copyright (C) 2016 Martin Etmajer
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
        class Alpine < Os
          def update_packages_command
            @config[:update_package_repos] ? "#{sudo_env('apk')} update" : nil
          end

          def install_command
            <<-INSTALL

            if [ ! $(which ansible) ]; then
              #{update_packages_command}
              #{sudo_env('apk')} add ansible git
            fi
            INSTALL
          end
        end
      end
    end
  end
end
