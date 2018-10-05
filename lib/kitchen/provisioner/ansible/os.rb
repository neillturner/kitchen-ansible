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

require 'json'
require 'kitchen/provisioner/ansible/os/debian'
require 'kitchen/provisioner/ansible/os/redhat'
require 'kitchen/provisioner/ansible/os/fedora'
require 'kitchen/provisioner/ansible/os/amazon'
require 'kitchen/provisioner/ansible/os/suse'
require 'kitchen/provisioner/ansible/os/darwin'
require 'kitchen/provisioner/ansible/os/alpine'
require 'kitchen/provisioner/ansible/os/openbsd'
require 'kitchen/provisioner/ansible/os/freebsd'

module Kitchen
  module Provisioner
    module Ansible
      class Os
        attr_accessor :name

        def initialize(name, config)
          @config = config
          @name = name
        end

        def self.make(platform, config)
          return nil if platform == ''

          case platform
          when 'debian', 'ubuntu'
            return Debian.new(platform, config)
          when 'redhat', 'centos'
            return Redhat.new(platform, config)
          when 'fedora'
            return Fedora.new(platform, config)
          when 'amazon'
            return Amazon.new(platform, config)
          when 'suse', 'opensuse', 'sles'
            return Suse.new(platform, config)
          when 'darwin', 'mac', 'macos', 'macosx'
            return Darwin.new(platform, config)
          when 'alpine'
            return Alpine.new(platform, config)
          when 'openbsd'
            return Openbsd.new(platform, config)
          when 'freebsd'
            return Freebsd.new(platform, config)
          end

          nil
        end

        # Helpers
        def sudo_env(pm)
          s = @config[:https_proxy] ? "https_proxy=#{@config[:https_proxy]}" : nil
          p = @config[:http_proxy] ? "http_proxy=#{@config[:http_proxy]}" : nil
          n = @config[:no_proxy] ? "no_proxy=#{@config[:no_proxy]}" : nil
          p || s ? "#{sudo('env')} #{p} #{s} #{n} #{pm}" : "#{sudo(pm)}"
        end

        # Taken from https://github.com/test-kitchen/test-kitchen/blob/master/lib/kitchen/provisioner/base.rb
        def sudo(script)
          @config[:sudo] ? "#{@config[:sudo_command]} #{script}" : script
        end

        def etc_ansible_path
          '/etc/ansible'
        end
      end
    end
  end
end
