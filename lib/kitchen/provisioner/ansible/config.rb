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
#
# See https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md
# for documentation configuration parameters with ansible_playbook provisioner.
#

require 'json'

module Kitchen

  module Provisioner

    module Ansible
      #
      # Ansible Playbook provisioner.
      #
      class Config
        include Kitchen::Configurable

        attr_reader :instance

        default_config :ansible_verbose, false
        default_config :require_ansible_omnibus, false
        default_config :ansible_omnibus_url, nil
        default_config :ansible_omnibus_remote_path, '/opt/ansible'
        default_config :ansible_version, nil
        default_config :require_ansible_repo, true
        default_config :extra_vars, {}
        default_config :tags, []
        default_config :ansible_apt_repo, "ppa:ansible/ansible"
        default_config :ansible_yum_repo, "https://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm"
        default_config :chef_bootstrap_url, "https://www.getchef.com/chef/install.sh"
        default_config :requirements_path, false
        default_config :ansible_verbose, false
        default_config :ansible_verbosity, 1
        default_config :ansible_check, false
        default_config :ansible_diff, false
        default_config :ansible_platform, ''
        default_config :update_package_repos, true

        default_config :playbook do |provisioner|
          provisioner.calculate_path('default.yml', :file) or
            raise "No playbook found or specified!  Please either set a playbook in your .kitchen.yml config, or create a default wrapper playbook for your role in test/integration/playbooks/default.yml or test/integration/default.yml"
        end

        default_config :roles_path do |provisioner|
          provisioner.calculate_path('roles') or
            raise 'No roles_path detected. Please specify one in .kitchen.yml'
        end

        default_config :group_vars_path do |provisioner|
          provisioner.calculate_path('group_vars', :directory)
        end

        default_config :additional_copy_path do |provisioner|
          provisioner.calculate_path('additional_copy', :directory)
        end

        default_config :host_vars_path do |provisioner|
          provisioner.calculate_path('host_vars', :directory)
        end

        default_config :modules_path do |provisioner|
          provisioner.calculate_path('modules', :directory)
        end

        default_config :ansiblefile_path do |provisioner|
          provisioner.calculate_path('Ansiblefile', :file)
        end

        default_config :filter_plugins_path do |provisioner|
          provisioner.calculate_path('filter_plugins', :directory)
        end

        default_config :ansible_vault_password_file do |provisioner|
          provisioner.calculate_path('ansible-vault-password', :file)
        end

        def initialize(config = {})
          init_config(config)
        end

        def set_instance(instance)
          @instance = instance
        end

        def []=(attr, val)
          config[attr] = val
        end

        def [](attr)
          config[attr]
        end

        def key?(k)
          return config.key?(k)
        end

        def calculate_path(path, type = :directory)

          if not instance
            raise "Please ensure that an instance is provided before calling calculate_path"
          end

          base = config[:test_base_path]
          candidates = []
          candidates << File.join(base, instance.suite.name, 'ansible', path)
          candidates << File.join(base, instance.suite.name, path)
          candidates << File.join(base, path)
          candidates << File.join(Dir.pwd, path)
          candidates << File.join(Dir.pwd) if path == 'roles'

          candidates.find do |c|
            type == :directory ? File.directory?(c) : File.file?(c)
          end
        end


      end

    end
  end

end
