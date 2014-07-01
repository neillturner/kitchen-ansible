# kitchen-ansible
A Test Kitchen Provisioner for Ansible

The provider works by passing the ansible repository based on attributes in .kitchen.yml & calling ansible-playbook.

It install ansible on the server and run ansible-playbook running on localhost.

This provider has been tested against the Ubuntu 1204 and Centos 6.5 boxes running in vagrant/virtualbox.

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
