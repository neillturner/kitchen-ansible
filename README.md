# kitchen-ansible
A Test Kitchen Provisioner for Ansible

The provider works by passing the ansible repository based on attributes in .kitchen.yml & calling ansible apply.

This provider has been tested against the Ubuntu 1204 and Centos 6.5 boxes running in vagrant/virtualbox.

## Requirements
You'll need a driver box without a chef installation so ansible can be installed.

## Installation & Setup
You'll need the test-kitchen & kitchen-ansible gem's installed in your system, along with kitchen-vagrant or some ther suitable driver for test-kitchen.

Please see the Provisioner Options (https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md).