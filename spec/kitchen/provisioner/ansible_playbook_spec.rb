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

require 'spec_helper'

# Work around for lazy loading
require 'kitchen/provisioner/ansible_playbook'

describe Kitchen::Provisioner::AnsiblePlaybook do
  let(:logged_output)   { StringIO.new }
  let(:logger)          { Logger.new(logged_output) }
  let(:platform) do
    instance_double(Kitchen::Platform, os_type: nil)
  end

  let(:custom_config) do
    {
      test_base_path: '/b',
      kitchen_root: '/r',
      log_level: :info,
      playbook: 'playbook.yml',
      ansible_vault_password_file: 'spec/fixtures/vault_password_file',
      ansible_inventory_file: 'spec/fixtures/hosts',
      ansible_extra_flags: '--skip-tags=skipme'
    }
  end

  let(:config) do
    custom_config.dup
  end

  let(:suite) do
    instance_double('Kitchen::Suite', name: 'fries')
  end

  let(:instance) do
    instance_double('Kitchen::Instance',
                    name: 'coolbeans',
                    logger: logger,
                    suite: suite,
                    platform: platform)
  end

  let(:provisioner) do
    Kitchen::Provisioner::AnsiblePlaybook.new(config).finalize_config!(instance)
  end

  describe '#run_command' do
    it 'should give a sane run_command' do
      expect(provisioner.run_command).to match(/ansible-playbook.*--skip-tags=skipme.*/)
    end
  end

  describe '#prepare_ansible_vault_password_file' do
    it 'copies the password file to the sandbox when present' do
      allow(provisioner).to receive(:sandbox_path).and_return(Dir.mktmpdir)
      provisioner.send(:prepare_ansible_vault_password_file)
    end

    it 'noops when the ansible_vault_password_file is not configured' do
      provision_without_vault_configured = Kitchen::Provisioner::AnsiblePlaybook.new(
        config.tap { |config| config.delete(:ansible_vault_password_file) }
      ).finalize_config!(instance)

      allow(provision_without_vault_configured).to receive(:sandbox_path).and_return(Dir.mktmpdir)

      expect { provision_without_vault_configured.send(:prepare_ansible_vault_password_file) }.not_to raise_error
    end
  end

  describe '#prepare_inventory' do
    it 'copies the inventory file to the sandbox when present' do
      allow(provisioner).to receive(:sandbox_path).and_return(Dir.mktmpdir)
      provisioner.send(:prepare_inventory)
    end
  end

  describe 'configuration' do
    it 'should not be verbose by default' do
      expect(provisioner[:ansible_verbose]).to eq false
      expect(provisioner.send(:ansible_verbose_flag)).to be_nil
    end

    it 'should be configured to be verbose when ansible_verbose is set' do
      config[:ansible_verbose] = true
      expect(provisioner[:ansible_verbose]).to eq true
    end

    it 'should generate the flag for 4 verbosity levels' do
      config[:ansible_verbose] = true
      (1..4).each do |i|
        config[:ansible_verbosity] = i
        # puts "Setting ansible_verbosity to: #{config[:ansible_verbosity]}"
        # puts "ansible_verbose_flag is: #{provisioner.send(:ansible_verbose_flag)}"
        expect(provisioner.send(:ansible_verbose_flag).count('v')).to eq i
      end
    end

    it 'should understand log level names and convert to a number of -v flags' do
      config[:ansible_verbose] = true
      { :info => 1, :warn => 2, :debug => 3, :trace => 4, 'info' => 1, 'warn' => 2, 'debug' => 3, 'trace' => 4 }.each do |log_level, i|
        # puts "Setting ansible_verbosity to: #{log_level} which converts to integer: #{i}"
        # puts "ansible_verbose_flag is: #{provisioner.send(:ansible_verbose_flag)}"
        config[:ansible_verbosity] = log_level
        expect { provisioner.send(:ansible_verbose_flag) }.to_not raise_error
        expect(provisioner.send(:ansible_verbose_flag).count('v')).to eq i
      end
    end

    it 'should raise an error if invalid verbosity level is given' do
      config[:ansible_verbose] = true
      [1e10, 0, -1, '-', :foobar, 'abc', { foo: 'bar' }, [1, 2, 3]].each do |invalid_level|
        # puts "Setting ansible_verbosity to: #{invalid_level} which should raise error"
        config[:ansible_verbosity] = invalid_level
        expect { provisioner.send(:ansible_verbose_flag) }.to raise_error("Invalid ansible_verbosity setting.  Valid values are: 1, 2, 3, 4 OR :info, :warn, :debug, :trace")
      end
    end
  end

  describe '#diagnose' do
    it 'should give a sane diagnostic information' do
      expect { provisioner.send(:diagnose) }.to_not raise_error
      custom_config.each do |k, v|
        expect(provisioner.send(:diagnose)[k]).to eq v
      end
    end
  end

  describe '#role_name' do
    it 'should be empty if the roles_path ends with "roles"' do
      config[:roles_path] = '/some/path/to/roles'
      expect(provisioner.send(:role_name)).to eq ''
    end
    it 'should be the basename of the roles_path does not end with "roles"' do
      config[:roles_path] = '/some/path'
      expect(provisioner.send(:role_name)).to eq 'path'
    end
    it 'should be the value from configuration if defined' do
      config[:role_name] = 'my-role'
      expect(provisioner.send(:role_name)).to eq 'my-role'
    end
  end

  describe '#prepare_roles' do
    it 'should correct cp when requirements_path not include path' do
      config[:requirements_path] = '.gitignore'

      sandbox_path = Dir.mktmpdir
      allow(provisioner).to receive(:sandbox_path).and_return(sandbox_path)

      expect { provisioner.send(:prepare_roles) }.to_not raise_error
      expect(File.exists?(File.join(sandbox_path, config[:requirements_path]))).to eq(true)
    end

    it 'should correct cp when requirements_path include path' do
      config[:requirements_path] = 'spec/data/requirements.yml'

      sandbox_path = Dir.mktmpdir
      allow(provisioner).to receive(:sandbox_path).and_return(sandbox_path)

      expect { provisioner.send(:prepare_roles) }.to_not raise_error
      expect(File.exists?(File.join(sandbox_path, config[:requirements_path]))).to eq(true)
    end

    it 'should ignore .git directories when ignore_paths_from_root is set' do
      config[:ignore_paths_from_root] = ['.git']

      sandbox_path = Dir.mktmpdir
      allow(provisioner).to receive(:sandbox_path).and_return(sandbox_path)

      expect { provisioner.send(:prepare_roles) }.to_not raise_error
    end

    it 'should correct cp when role_name is set' do
      config[:role_name] = 'my-role'

      sandbox_path = Dir.mktmpdir
      allow(provisioner).to receive(:sandbox_path).and_return(sandbox_path)

      expect { provisioner.send(:prepare_roles) }.to_not raise_error
      expect(Dir.entries(File.join(sandbox_path, 'roles', config[:role_name])).size).to be > 2
    end
  end
end
