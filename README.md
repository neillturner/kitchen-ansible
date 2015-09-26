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
  verifier:
    ruby_bindir: '/usr/bin'
```
where `/usr/bin` is the location of the ruby command. 


## Test-Kitchen/Ansible/Serverspec

In the root directory for your Ansible role:

Create a `.kitchen.yml`, much like one the described above:
    
```yaml
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

  verifier:
    ruby_bindir: '/usr/bin'    

  suites:
    - name: default
```

Then for serverspec:
    
```bash
  mkdir -p test/integration/default/serverspec/localhost
  echo "require 'serverspec'" >> test/integration/default/serverspec/spec_helper.rb
  echo "set :backend, :exec" >> test/integration/default/serverspec/spec_helper.rb
```

Create a basic playbook `test/integration/default.yml` so that kitchen can use your role (this should include any dependencies for your role):
    
```yaml
  ---
  - name: wrapper playbook for kitchen testing "my_role"
    hosts: localhost
    roles:
      - my_role
```

Create your serverspec tests in `test/integration/default/serverspec/localhost/my_roles_spec.rb`:
    
```ruby
  require 'spec_helper'

  if os[:family] == 'ubuntu'
        describe '/etc/lsb-release' do
          it "exists" do
              expect(file('/etc/lsb-release')).to be_file
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
```

### Testing multiple playbooks
To test different playbooks in different suites you can easily overwrite the provisioner settings in each suite seperately.
```yaml
---
  driver:
    name: vagrant

  provisioner:
    name: ansible_playbook

  platforms:
    - name: ubuntu-12.04
      driver_config:
        box: ubuntu/precise32
    - name: centos-7
      driver_config:
         box: chef/centos-7.0

  suites:
    - name: database
      provisioner:
        playbook: postgres.yml
        hosts: database
    - name: application
      provisioner:
        playbook: web_app.yml
        hosts: web_application
```
### Alternative Virtualization/Cloud providers for Vagrant
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

## Custom ServerSpec or AnsibleSpec Invocation 

 Instead of using the busser use a custom serverspec invocation using [shell verifier](https://github.com/higanworks/kitchen-verifier-shell) to call it. 
With such setup there is no dependency on busser and any other chef library.

Also you can specify you tests in a different directory structure or even call [ansible spec](https://github.com/volanja/ansible_spec) instead of server spec and have tests in ansible_spec structure 

Using a structure like
```yaml
verifier:                                                                       
  name: shell                                                                   
  remote_exec: true                                                             
  command: |                                                                    
    sudo -s <<SERVERSPEC                                                        
    cd /opt/gdc/serverspec-core                                                 
    export SERVERSPEC_ENV=$EC2DATA_ENVIRONMENT                                  
    export SERVERSPEC_BACKEND=exec                                              
    serverspec junit=true tag=~skip_in_kitchen check:role:$EC2DATA_TYPE               
    SERVERSPEC
```

where `serverspec` is a wrapper around `rake` invocation.
Use a `Rakefile` similar to one in https://github.com/vincentbernat/serverspec-example.

With such approach we can achieve flexibility of running same test suite both in test kitchen and actual, even production, instances.

Beware: kitchen-shell-verifier is not yet merged into test-kitchen upstream so using separate gem is unavoidable so far
