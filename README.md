# kitchen-ansible

[![Gem Version](https://badge.fury.io/rb/kitchen-ansible.svg)](http://badge.fury.io/rb/kitchen-ansible)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-ansible?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-ansible)
[![Build Status](https://travis-ci.org/neillturner/kitchen-ansible.png)](https://travis-ci.org/neillturner/kitchen-ansible)

A Test Kitchen Provisioner for Ansible.

The provisioner works by passing the Ansible repository based on attributes in `.kitchen.yml` & calling `ansible-playbook`.

It installs Ansible on the server and runs `ansible-playbook` using host localhost.

It has been tested against the Ubuntu 12.04, Ubuntu 14.04, Centos 6.5 and Debian 6/7/8  boxes running in vagrant/virtualbox.

## Requirements
- [Test Kitchen](https://github.com/test-kitchen/test-kitchen).
- a driver box without a Chef installation so Ansible can be installed.

## Installation & Setup
Install the `kitchen-ansible` gem in your system, along with [kitchen-vagrant](https://github.com/test-kitchen/kitchen-vagrant) or [kitchen-docker](https://github.com/test-kitchen/kitchen-docker) or any other suitable driver:

```
gem install kitchen-ansible
gem install kitchen-vagrant
```

## Example .kitchen.yml file

Based on the [Tomcat Standalone](https://github.com/ansible/ansible-examples/tree/master/tomcat-standalone) example:

```yaml
---
driver:
  name: vagrant

provisioner:
  name: ansible_playbook
  roles_path: roles
  hosts: tomcat-servers
  require_ansible_repo: true
  ansible_verbose: true
  ansible_version: latest

platforms:
  - name: nocm_centos-6.5
    driver_plugin: vagrant
    driver_config:
      box: nocm_centos-6.5
      box_url: http://puppet-vagrant-boxes.puppetlabs.com/centos-65-x64-virtualbox-nocm.box
      network:
      - ['forwarded_port', {guest: 8080, host: 8080}]
      - ['private_network', {ip: '192.168.33.11'}]
```

## Windows Support

Windows is supported by creating a linux server to run Ansible with software required to support winrm. Then the winrm connection is used to configure the windows server.

In `.kitchen.yml` set:

```yaml
  ansible_connection: winrm
  require_windows_support: true
  require_chef_for_busser: false
```

See the [Ansible Windows repo](https://github.com/neillturner/ansible_windows_repo) example.

## Using Roles from Ansible Galaxy 

Roles can be used from the Ansible Galaxy using two methods: 

1. Specify a `requirements.yml` file in your Ansible repository. For more details see [here](http://docs.ansible.com/ansible/galaxy.html).

2. Use `librarian-ansible` by creating an `Ansiblefile` in the top level of the repository and `kitchen-ansible` will automatically call `librarian-ansible` during convergence. For a description of setting up an `Ansiblefile` see [here](https://werner-dijkerman.nl/2015/08/15/using-librarian-ansible-to-install-ansible-roles-from-gitlab/).

## Tips

To  use a single ~/.kitchen/config.yml file with multiple reposities by setting the WORKSPACE environment variable:

```yaml
role_path: <%= ENV['WORKSPACE'] %>/roles 
```

You can easily skip previous instructions and jump directly to the broken statement you just fixed by passing an environment variable. Add the following to your `.kitchen.yml`:

```yaml
provisioner:
  name: ansible_playbook
  ansible_extra_flags: <%= ENV['ANSIBLE_EXTRA_FLAGS'] %>
```

Then run:

```
$ ANSIBLE_EXTRA_FLAGS='--start-at-task="myrole | name of last working instruction"' kitchen converge
```

You save a lot of time not running working instructions.


## Ruby install to run Serverspec verify

By default test-kitchen installs Chef to get a Ruby version suitable to run Serverspec in the `verify` step.
Instead Ruby can just be installed by specifying the provisioner option:

```yaml
require_ruby_for_busser: true
```
And set the verifier section:
```yaml
verifier:
  name: serverspec
  sudo_path: true

suites:
  - name: ansible
    driver_config:
      hostname: '54.229.34.169'
    verifier:
      patterns:
      - roles/tomcat/spec/tomcat_spec.rb
      bundler_path: '/usr/local/bin'
      rspec_path: '/usr/local/bin'
      env_vars:
        TARGET_HOST: 54.229.104.40
        LOGIN_USER: centos
        SUDO: true
        SSH_KEY: spec/test.pem
```

Please see the [Provisioner Options](https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md) for a complete listing.

## Test-Kitchen Ansiblespec

By using kitchen-verifier-serverspec and the Runner ansiblespec_runner tests can be run against multiple servers with multiple roles in the ansiblespec format.

Serverspec uses ssh to communicate with the server to be tested and reads the Ansible playbook and inventory files to determine the hosts to test and the roles for each host.

See example [https://github.com/neillturner/ansible_repo](https://github.com/neillturner/ansible_repo)

### Example usage to create Tomcat servers:

![test-kitchen, Ansible and ansiblespec](https://github.com/neillturner/ansible_repo/blob/master/kitchen-ansible.png "test-kitchen, ansible and ansiblespec")

See [ansible-sample-tdd](https://github.com/volanja/ansible-sample-tdd).

### Usage

#### Directory

In the Ansible repository specify:

* spec files with the roles.
* spec_helper in the spec folder (with code as below).

```
.
+-- roles
¦   +-- mariadb
¦   ¦   +-- spec
¦   ¦   ¦   +-- mariadb_spec.rb
¦   ¦   +-- tasks
¦   ¦   ¦   +-- main.yml
¦   ¦   +-- templates
¦   ¦       +-- mariadb.repo
¦   +-- nginx
¦       +-- handlers
¦       ¦   +-- main.yml
¦       +-- spec
¦       ¦   +-- nginx_spec.rb
¦       +-- tasks
¦       ¦   +-- main.yml
¦       +-- templates
¦       ¦   +-- nginx.repo
¦       +-- vars
¦           +-- main.yml
+-- spec
    +-- spec_helper.rb
    +-- my_private_key.pem
```


#### spec_helper

```ruby
require 'rubygems'
require 'bundler/setup'

require 'serverspec'
require 'pathname'
require 'net/ssh'

RSpec.configure do |config|
  set :host,  ENV['TARGET_HOST']
  # ssh options at http://net-ssh.github.io/ssh/v1/chapter-2.html
  # ssh via password
  set :ssh_options, :user => ENV['LOGIN_USER'], :paranoid => false, :verbose => :error, :password => ENV['LOGIN_PASSWORD'] if ENV['LOGIN_PASSWORD']
  # ssh via ssh key
  set :ssh_options, :user => ENV['LOGIN_USER'], :paranoid => false, :verbose => :error, :host_key => 'ssh-rsa', :keys => [ ENV['SSH_KEY'] ] if ENV['SSH_KEY']
  set :backend, :ssh
  set :request_pty, true
end
```

See [kitchen-verifier-serverspec](https://github.com/neillturner/kitchen-verifier-serverspec).

## Alternative Virtualization/Cloud providers for Vagrant
This could be adapted to use alternative virtualization/cloud providers such as Openstack/AWS/VMware Fusion according to whatever is supported by Vagrant.
```yaml
platforms:
  - name: ubuntu-12.04
    driver_config:
      provider: aws
      box: my_base_box
      # username is based on what is configured in your box/ami
      username: ubuntu
      customize:
        access_key_id: 'AKKJHG659868LHGLH'
        secret_access_key: 'G8t7o+6HLG876JGF/58'
        ami: ami-7865ab765d
        instance_type: t2.micro
        # more customisation can go here, based on what the vagrant provider supports
        #security-groups: []
```

## Notes

* The `default` in all of the above is the name of the test suite defined in the `suites` section of your `.kitchen.yml`, so if you have more than one suite of tests or change the name, you'll need to adapt the example accordingly.
* Serverspec test files *must* be named `_spec.rb`
* Since I'm using Vagrant, my `box` definitions refer to Vagrant boxes, either standard, published boxes available from [Atlas](http://atlas.hashicorp.com/boxes) or custom-created boxes (perhaps using [Packer](http://packer.io) and [bento](https://github.com/chef/bento), in which case you'll need to provide the URL in `box_url`.

