
# Provisioner Options

key | default value | Notes
----|---------------|--------
ansible_version | "latest"| desired version, affects apt installs
ansible_sudo | true | drives whether ansible-playbook is executed as root or as the current authenticated user
ansible_platform | naively tries to determine | OS platform of server
require_ansible_repo | true | Set if using a ansible install from yum or apt repo
ansible_apt_repo | "ppa:ansible/ansible" | apt repo. see https://launchpad.net /~ansible/+archive/ubuntu/ansible or rquillo/ansible
ansible_yum_repo | https://download.fedoraproject.org /pub/epel/6/i386/epel-release-6-8.noarch.rpm | yum repo
_for RH/Centos7 change to_ | http://dl.fedoraproject.org /pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm | 
enable_yum_epel  | false | enable yum EPEL repo  
ansible_sles_repo | http://download.opensuse.org/repositories /systemsmanagement/SLE_12/systemsmanagement.repo | zypper suse ansible repo
python_sles_repo | http://download.opensuse.org/repositories/devel: /languages:/python/SLE_12/devel:languages:python.repo | zypper suse python repo
require_ansible_omnibus | false | Set if using omnibus ansible pip install
ansible_omnibus_url | https://raw.githubusercontent.com /neillturner/omnibus-ansible/master/ansible_install.sh | omnibus ansible install location.
ansible_omnibus_remote_path | "/opt/ansible" | Server Installation location of an omnibus ansible install.
http_proxy | nil | use http proxy when installing puppet, packages and running puppet
https_proxy | nil | use https proxy when installing puppet, packages and running puppet
no_proxy | nil | list of URLs or IPs that should be excluded from proxying
roles_path | roles | ansible repo roles directory
group_vars_path | group_vars | ansible repo group_vars directory
host_vars_path | host_vars | ansible repo hosts directory
filter_plugins | filter_plugins | ansible repo filter_plugins directory
lookup_plugins | lookup_plugins | ansible repo lookup_plugins directory
additional_copy_path | | arbitrary array of files and directories to copy into test environment, relative to CWD. (eg, vars or included playbooks)
extra_vars | Hash.new | Hash to set the extra_vars passed to ansibile-playbook command
playbook | 'default.yml' | playbook for ansible-playbook to run
modules_path | | ansible repo manifests directory
ansible_verbose| false| Extra information logging
ansible_verbosity| 1| Sets the verbosity flag appropriately (e.g.: `1 => '-v', 2 => '-vv', 3 => '-vvv" ...`) Valid values are one of: `1, 2, 3, 4` OR `:info, :warn, :debug, :trace`.
ansible_check| false| Sets the `--check` flag when running Ansible
ansible_diff| false| Sets the `--diff` flag when running Ansible
update_package_repos| true| update OS repository metadata
ansiblefile_path | | Path to Ansiblefile
requirements_path | | Path to ansible-galaxy requirements
ansible_vault_password_file| | Path of Ansible Vault Password File
ansible_connection | local | Connection for Hosts and Groups
ansible_inventory_file | hosts | Custom inventory file
ansible_extra_flags | '' | Additional options to pass to `ansible-playbook` -- e.g.: `'--skip-tags=redis'`
require_ruby_for_busser|false|install ruby to run busser for tests
require_chef_for_busser|true|install chef to run busser for tests. NOTE: kitchen 1.4 only requires ruby to run busser so this is not required.
chef_bootstrap_url |https://www.getchef.com /chef/install.sh| the chef install
require_ansible_source | false | Install Ansible from source using method described here: http://docs.ansible.com/intro_installation.html#running-from-source. Only works on Debian/Ubuntu at present.

## Configuring Provisioner Options

The provisioner can be configured globally or per suite, global settings act as defaults for all suites, you can then customise per suite, for example:

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
      ansible_verbosity: 2
      ansible_diff: true

    platforms:
    - name: nocm_ubuntu-12.04
      driver_plugin: vagrant
      driver_config:
        box: nocm_ubuntu-12.04
        box_url: http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-12042-x64-vbox4210-nocm.box

    suites:
     - name: default
```

**NOTE:** With Test-Kitchen 1.4 you not longer need chef install to run the tests. You just need ruby installed version 1.9 or higher and also add to the .kitchen.yml file

```yaml
  verifier:
    ruby_bindir: '/usr/bin'
```
where /usr/bin is the location of the ruby command.


in this example, vagrant will download a box for ubuntu 1204 with no configuration management installed, then install the latest ansible and ansible playbook against a ansible repo from the /repository/ansible_repo directory using the default manifest site.yml

To override a setting at the suite-level, specify the setting name under the suite's attributes:

```yaml
    suites:
     - name: server
       attributes:
         extra_vars:
           server_installer_url: http://downloads.app.com/v1.0
         tags:
           - server
```

### Per-suite Structure

It can be beneficial to keep different Ansible layouts for different suites. Rather than having to specify the roles, modules, etc for each suite, you can create the following directory structure and they will automatically be found:

    $kitchen_root/ansible/$suite_name/roles
    $kitchen_root/ansible/$suite_name/modules
    $kitchen_root/ansible/$suite_name/Ansiblefile
