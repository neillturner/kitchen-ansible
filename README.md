# kitchen-ansible

[![Gem Version](https://badge.fury.io/rb/kitchen-ansible.svg)](http://badge.fury.io/rb/kitchen-ansible)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-ansible?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-ansible)
[![Build Status](https://travis-ci.org/neillturner/kitchen-ansible.png)](https://travis-ci.org/neillturner/kitchen-ansible)

A Test Kitchen Provisioner for Ansible

The provisioner works by passing the ansible repository based on attributes in `.kitchen.yml` & calling `ansible-playbook`.

It installs Ansible on the server and runs `ansible-playbook` using host localhost.

Has been tested against the Ubuntu 12.04 and Centos 6.5 boxes running in vagrant/virtualbox.

## Requirements
You'll need a driver box without a chef installation so ansible can be installed.

## Installation & Setup
You'll need the test-kitchen & kitchen-ansible gems installed in your system, along with [kitchen-vagrant](https://github.com/test-kitchen/kitchen-vagrant) or some other suitable driver for test-kitchen.

Please see the Provisioner Options (https://github.com/neillturner/kitchen-ansible/blob/master/provisioner_options.md).

## Example kitchen.yml file

based on the example ansible setup for tomcat at  https://github.com/ansible/ansible-examples/tree/master/tomcat-standalone

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

verifier:
  ruby_bindir: '/usr/bin'
```
**NOTE:** With Test-Kitchen 1.4 you no longer need chef install to run the tests. You just need ruby installed version 1.9 or higher and also add to the `.kitchen.yml` file

```yaml
provisioner:
  name: ansible_playbook
  hosts: test-kitchen
  require_chef_for_busser: false
  require_ruby_for_busser: true

verifier:
  ruby_bindir: '/usr/bin'
```
where `/usr/bin` is the location of the ruby command.

## Test-Kitchen Ansiblespec

This can run tests against multiple servers with multiple roles in any of three formats:
  * ansiblespec - tests are specified with the roles in the ansible repository. (default)
  * serverspec - tests are in test-kitchen serverspec format
  * spec - tests are stored in the spec directory with a directory for each role.

Serverspec using ssh to communicate with the server to be tested and reads the ansible playbook and inventory files to determine the hosts to test and the roles for each host.

Set pattern: 'serverspec' in the config.yml file (see below) to perform tests in test-kitchen serverspec format.
( See https://github.com/delphix/ansible-package-caching-proxy for an example of using test-kitchen serverspec).

Set pattern: 'spec' in the config.yml file (see below) to perform tests in for roles specified in the spec directory.

By default pattern: ansiblespec is set. See example [https://github.com/neillturner/ansible_repo](https://github.com/neillturner/ansible_repo)


### Example usage to create tomcat servers:

```
                                                                     TOMCAT SERVERS
     TEST KITCHEN              ANSIBLE AND SERVERSPEC
     WORKSTATION               SERVER                             +------------------------+
                             +-----------------------+            |   +---------+          |
                             |                       |            |   |Tomcat   |          |
+-------------------+        |                   +---------------->   |         |          |
|                   |        |                   |   |            |   +---------+          |
|    Workstation    |        |                   |   |    +------->                        |
|    test-kitchen   |        |                   |   |    |       |                        |
|    kitchen-ansible|        |                   |   |    |       |                        |
|                   |  create|                   |   |    |       +------------------------+
|     CREATE +--------------->      install      |   |    |
|                   |  server|      and run      |   |    |
|     CONVERGE+-------------------->ANSIBLE  +---+   |    |       +------------------------+
|                   |        |               +-------------------->  +----------+          |
|                   |        | install and run       |    |       |  |Tomcat    |          |
|    VERIFY+------------------>Busser-ansiblespec +-------+       |  |          |          |
+-------------------+        |  +                 |  |            |  +----------+          |
                             |  +--->ServerSpec   +--------------->                        |
                             |                       |            |                        |
                             +-----------------------+            |                        |
                                                                  +------------------------+


                   * All connections over SSH

```

See [ansible-sample-tdd](https://github.com/volanja/ansible-sample-tdd)

### <a name="usage"></a> Usage

### Directory

In the ansible repository specify:

  * spec files with the roles.

  * spec_helper in the spec folder (with code as below).

  * test/integration/<suite>/ansiblespec containing config.yml and ssh private keys to access the servers.

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
+-- test
    +-- integration
        +-- default      # name of test-kitchen suite
            +-- ansiblespec
                +-- config.yml

```


## <a name="spec_helper"></a> spec_helper

```
require 'rubygems'
require 'bundler/setup'

require 'serverspec'
require 'pathname'
require 'net/ssh'

RSpec.configure do |config|
  set :host,  ENV['TARGET_HOST']
  # ssh via password
  set :ssh_options, :user => 'root', :password => ENV['LOGIN_PASSWORD'] if ENV['LOGIN_PASSWORD']
  # ssh via ssh key
  set :ssh_options, :user => 'root', :host_key => 'ssh-rsa', :keys => [ ENV['SSH_KEY'] ] if ENV['SSH_KEY']
  set :backend, :ssh
  set :request_pty, true
end
```

## <a name="config.yml"></a> config.yml

This goes in directory test/integration/default/ansiblespec  where default is the name of test-kitchen suite

```
---
-
  playbook: default.yml
  inventory: hosts
  kitchen_path: '/tmp/kitchen'
  pattern: 'ansiblespec'    # or spec or serverspec
  ssh_key: 'spec/my_private_key.pem'
  login_password: 'myrootpassword'
```

See [busser-ansiblespec](https://github.com/neillturner/busser-ansiblespec)

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
          access_key_id: "AKKJHG659868LHGLH"
          secret_access_key: "G8t7o+6HLG876JGF/58"
          ami: ami-7865ab765d
          instance_type: t2.micro
          # more customisation can go here, based on what the vagrant provider supports
          #security-groups: []
```

*Notes*

* The `default` in all of the above is the name of the test suite defined in the 'suites' section of your `.kitchen.yml`, so if you have more than suite of tests or change the name, you'll need to adapt my example accordingly.
* serverspec test files *must* be named `_spec.rb`
* Since I'm using Vagrant, my `box` definitions refer to Vagrant boxes, either standard, published boxes available from <http://atlas.hashicorp.com/boxes> or custom-created boxes (perhaps using [Packer][packer] and [bento][bento]), in which case you'll need to provide the url in `box_url`.

[Serverspec]: http://serverspec.org
[packer]: https://packer.io
[bento]: https://github.com/chef/bento


## Tips

You can easily skip previous instructions and jump directly to the broken statement you just fixed by passing
an environment variable. Add folloing to your .kitchen.yml

```yaml
provisioner:
  name: ansible_playbook
  ansible_extra_flags: <%= ENV['ANSIBLE_EXTRA_FLAGS'] %>
```

run:

`ANSIBLE_EXTRA_FLAGS='--start-at-task="myrole | name of last working instruction"' kitchen converge`

You save a LOT of time not running working instructions.
