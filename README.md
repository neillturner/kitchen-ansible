# kitchen-ansible
A Test Kitchen Provisioner for Ansible

The provider works by passing the ansible repository based on attributes in .kitchen.yml & calling ansible-playbook.

It install ansible on the server and runs ansible-playbook using host localhost.

Has been tested against the Ubuntu 1204 and Centos 6.5 boxes running in vagrant/virtualbox.

## Requirements
You'll need a driver box without a chef installation so ansible can be installed.

## Installation & Setup
You'll need the test-kitchen & kitchen-ansible gem's installed in your system, along with kitchen-vagrant or some other suitable driver for test-kitchen.

Please see the Provisioner Options (https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md).

## Example kitchen.yml file

based on the example ansible setup for tomcat at  https://github.com/ansible/ansible-examples/tree/master/tomcat-standalone
```
---
driver:
    name: vagrant

provisioner:
  name: ansible_playbook
  roles_path: roles
  hosts: tomcat-servers
  require_ansible_repo: true
  ansible_verbose: true
  ansible_version:   1.6.2-1.el6
  extra_vars:
    a: b

platforms:
  - name: nocm_centos-6.5
    driver_plugin: vagrant
    driver_config:
      box: nocm_centos-6.5
      box_url: http://puppet-vagrant-boxes.puppetlabs.com/centos-65-x64-virtualbox-nocm.box
      network:
      - ['forwarded_port', {guest: 8080, host: 8080}]
      - [ 'private_network', { ip: '192.168.33.11' } ]
```

## Test-Kitchen/Ansible/Serverspec

In the root directory for your Ansible role:

Create a `.kitchen.yml`, much like one the described above:

      ---
      driver:
        name: vagrant

      provisioner:
        name: ansible_playbook
        playbook: default.yml
        ansible_yum_repo: "https://download.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm"
        ansible_verbose: true
        ansible_verbosity: 3
        hosts: all

      platforms:
        - name: ubuntu-12.04
          driver_config:
            box: ubuntu/precise32
        - name: centos-7
          driver_config:
             box: chef/centos-7.0

      suites:
        - name: default

Then for serverspec:

      mkdir -p test/integration/default/serverspec/localhost
      echo "require 'serverspec'" >> test/integration/default/serverspec/spec_helper.rb
      echo "set :backend, :exec" >> test/integration/default/serverspec/spec_helper.rb

Create a basic playbook `test/integration/default.yml` so that kitchen can use your role (this should include any dependencies for your role):

      ---
      - name: wrapper playbook for kitchen testing "my_role"
        hosts: localhost
        roles:
          - my_role

Create your serverspec tests in `test/integration/default/serverspec/localhost/my_roles_spec.rb`:

      require 'spec_helper'

      if os[:family] == 'ubuntu'
            describe '/etc/lsb-release' do
              it "exists" do
                  expect(file('/etc/lsb-release').to be_file
              end
            end
      end

      if os[:family] == 'redhat'
        describe '/etc/redhat-release' do
          it "exists" do
              expect(file('/etc/redhat-release')).to be_file
          end
        end
      end

*Notes*

* The `default` in all of the above is the name of the test suite defined in the 'suites' section of your `.kitchen.yml`, so if you have more than suite of tests or change the name, you'll need to adapt my example accordingly.
* serverspec test files *must* be named `_spec.rb`
* Since I'm using Vagrant, my `box` definitions refer to Vagrant boxes, either standard, published boxes available from <http://atlas.hashicorp.com/boxes> or custom-created boxes (perhaps using [Packer][packer] and [bento][bento]), in which case you'll need to provide the url in `box_url`.
* This could be adapted to using Openstack/AWS/whatever VMs as supported by Vagrant.

[Serverspec]: http://serverspec.org
[packer]: https://packer.io
[bento]: https://github.com/chef/bento

