# Ansible Install Options

Kitchen-ansible is very flexible in how it installs ansible:

It installs it in the following order:

* if require_ansible_omnibus is set to true

  Installs using the omnibus_ansible script specified in the ansible_omnibus_url parameter and passes the ansible_version if specied as -v option.

* If require_ansible_source is set to true

  Install require packages and download the ansible source from github from  master or from a branch specified in the parameter install_source_rev.

* if require_pip is set to true

  Install require packages and then installs ansible using the python pip command and ansible version must be specified. This allows a specific version of ansible to be installed.

* if require_ansible_repo is set to true (the default)

  Installs from the operation system repository only with the ansible version that is in the particular repository and will use the ansible_version in the package name where appropriate.
  
NOTE:  Set to ansible_package_name to 'ansible' when installing from the CentOS/Redhat extras repo, instead of the EPEL.

# Provisioner Options

kitchen-ansible runs the ansible playbook command http://linux.die.net/man/1/ansible-playbook with options from parameters in the kitchen.yml file:

key | default value | Notes
----|---------------|--------
additional_copy_path | | Arbitrary array of files and directories to copy into test environment e.g. vars or included playbooks. See below section Copying Additional Files
additional_copy_role_path | |  Arbitrary array of files and directories to copy into test environment and are appended to the ANSIBLE_ROLES_PATH env var when running ansible. See below section Copying Additional Files
additional_ssh_private_keys | | List of additional ssh private key files to be added to ~/.ssh
ansible_apt_repo | ppa:ansible/ansible | `apt` repo; see `https://launchpad.net` `/~ansible/+archive/ubuntu/ansible` or `rquillo/ansible`
ansible_binary_path | NULL | If specified this will override the location where `kitchen` tries to run `ansible-playbook` from, i.e. `ansible_binary_path: /usr/local/bin`
ansible_check | false | Sets the `--check` flag when running Ansible
ansible_connection | local | use `ssh` if the host is not `localhost` (Linux) or `winrm` (Windows) or `none` if defined in inventory
ansible_cfg_path | ansible.cfg | location of custom ansible.cfg to get copied into test environment
ansible_diff | false | Sets the `--diff` flag when running Ansible
ansible_extra_flags |  | Additional options to pass to ansible-playbook, e.g. `'--skip-tags=redis'`
ansible_host_key_checking | true | Strict host key checking in ssh
ansible_inventory |  | Static or dynamic inventory file or directory or 'none' if defined in `ansible.cfg`
ansible_limit |  | Further limits the selected host/group patterns
ansible_omnibus_remote_path | /opt/ansible | Server installation location of an Omnibus Ansible install
ansible_omnibus_url | `https://raw.githubusercontent.com` `/neillturner/omnibus-ansible` `/master/ansible_install.sh` | Omnibus Ansible install location
ansible_package_name |  | Set to ansible when installing from the CentOS/Redhat extras repo, instead of the EPEL.
ansible_platform | Naively tries to determine | OS platform of server
ansible_playbook_command | | Override the Ansible playbook command
ansible_sles_repo | `http://download.opensuse.org/repositories` `/systemsmanagement/SLE_12` `/systemsmanagement.repo` | Zypper SuSE Ansible repo
ansible_source_url | `git://github.com/ansible/ansible.git` | Git URL of Ansible source
ansible_source_rev | | Branch or tag to install Ansible source
ansible_sudo | true | Determines whether `ansible-playbook` is executed as root or as the current authenticated user
ansible_vault_password_file | | Path to Ansible Vault password file
ansible_verbose | false | Extra information logging
ansible_verbosity | 1 | Sets the verbosity flag appropriately, e.g.: `1 => '-v', 2 => '-vv', 3 => '-vvv' ...`. Valid values are: `1, 2, 3, 4` or `:info, :warn, :debug, :trace`
ansible_version | latest | Desired version, only affects `apt-get` installs
ansible_yum_repo | nil | `yum` repo for EL platforms
ansiblefile_path | | Path to Ansiblefile
callback_plugins_path | callback_plugins | Ansible repo `callback_plugins` directory
chef_bootstrap_url | `https://www.getchef.com/chef/install.sh` | The Chef install
custom_pre_install_command | nil | Custom shell command to be used at beginning of install stage. Can be multiline.
custom_pre_play_command | nil | Custom shell command to be used before the ansible play stage. Can be multiline. See examples below.
custom_post_install_command | nil | Custom shell command to be used at after the install stage. Can be multiline.
custom_post_play_command | nil | Custom shell command to be used after the ansible play stage. Can be multiline. See examples below.
enable_yum_epel | false | Enable the `yum` EPEL repo
env_vars | Hash.new | Hash to set environment variable to use with `ansible-playbook` command
extra_vars | Hash.new | Hash to set the `extra_vars` passed to `ansible-playbook` command
extra_vars_file | nil | file containing environment variables e.g. `private_vars/production.yml site.yml` Don't prefix with a @ sign.
filter_plugins_path | filter_plugins | Ansible repo `filter_plugins` directory
group_vars_path | group_vars | Ansible repo group_vars directory
host_vars_path | host_vars | Ansible repo hosts directory
hosts |  | Create Ansible hosts file for localhost with this server group or list of groups
http_proxy | nil | Use HTTP proxy when installing Ansible, packages and running Ansible
https_proxy | nil | Use HTTPS proxy when installing Ansible, packages and running Ansible
idempotency_test | false | Enable to test Ansible playbook idempotency
ignore_extensions_from_root | ['.pyc'] | allow extensions to be ignored when copying from roles using additional_copy_role_path or doing recursive_additional_copy_path
ignore_paths_from_root | [] | allow extra paths to be ignored when copying from roles using additional_copy_role_path or using recursive_additional_copy_path
kerberos_conf_file | | Path of krb5.conf file using in Windows support
library_plugins_path | library | Ansible repo library plugins directory
lookup_plugins_path | lookup_plugins | Ansible repo `lookup_plugins` directory
max_retries | 1 | maximum number of retry attempts of converge command
modules_path | | Ansible repo manifests directory
no_proxy | nil | List of URLs or IPs that should be excluded from proxying
playbook | default.yml | Playbook for `ansible-playbook` to run
private_key | | ssh private key file for ssh connection
python_sles_repo | `http://download.opensuse.org/repositories` `/devel:/languages:/python/SLE_12` `/devel:languages:python.repo` | Zypper SuSE python repo
recursive_additional_copy_path | | Arbitrary array of files and directories to copy into test environment. See below section Copying Additional Files
require_ansible_omnibus | false | Set to `true` if using Omnibus Ansible `pip` install
require_ansible_repo | true | Set if installing Ansible from a `yum` or `apt` repo
require_ansible_source | false | Install Ansible from source using method described [here](http://docs.ansible.com/intro_installation.html#running-from-source). Only works on Debian/Ubuntu at present
require_chef_for_busser | true | Install Chef to run Busser for tests. NOTE: kitchen 1.4 only requires Ruby to run Busser so this is not required.
require_pip | false | Set to `true` if Ansible is to be installed through `pip`).
require_ruby_for_busser | false | Install Ruby to run Busser for tests
require_windows_support | false | Install [Windows support](http://docs.ansible.com/ansible/intro_windows.html)
requirements_path | | Path to Ansible Galaxy requirements
retry_on_exit_code | [] | Array of exit codes to retry converge command against
role_name | | use when the repo name does not match the name the role is published as.
roles_path | roles | Ansible repo roles directory
shell_command | 'sh' | Shell command to use, usually an alias for bash. may need to set to bash.
show_command_output | false | Show output of commands that are run to provision system.
ssh_known_hosts | | List of hosts that should be added to ~/.ssh/known_hosts
sudo_command | sudo -E | `sudo` command; change to `sudo -E -H` to be consistent with Ansible
update_package_repos | true | Update OS repository metadata
wait_for_retry | 30 | number of seconds to wait before retrying converge command

## Ansible Inventory 

Ansible has the concept of an [inventory](http://docs.ansible.com/ansible/latest/intro_inventory.html).

Ansible then connects to these servers and processes the playbook against the server.

See also [Host inventories](https://ansible-tips-and-tricks.readthedocs.io/en/latest/ansible/inventory/).


### ansible Inventory parameter 

if you have an ansible inventory file you can specify it in the ansible_inventory parameter in the .kitchen.yml file.
```yaml
  ansible_inventory: myinventoryfile.txt
```  
or if you have an ansible.cfg  file specify
```yaml
  ansible_inventory: none 
``` 
it will look for the file in the root of your repository. 

or it can be a directory from the root of your repository and contain scripts to implement [dynamic inventory](http://docs.ansible.com/ansible/latest/intro_dynamic_inventory.html) 

### hosts parameter

if you don't specify an inventory file then you must specify the hosts parameter in the .kitchen.yml file. 

kitchen ansible uses this information to create a hosts file that is used by ansible with the ansible command is run. 
  
it can either be a name of a single server

```yaml
hosts: myhost 
```

or any array of hosts: 

```yaml
hosts: 
  - myhost1
  - myhost2
```  

the hosts file that is generated always contains in the first line 

```yaml
localhost ansible_connection=local
```
so that it will process against the locahost. 

and it will create a hosts file that includes the hosts you specify

```yaml
localhost ansible_connection=local
myhost1
myhost2
localhost
```


## Copying Additional Files

Several parameters have been developed rather organically to support the requirement to copy additional files beyond the ones in the standard ansible locations.
* These could be used for the verification phase later
* additional files required by the application
* or these could be ansible roles

### additional_copy_path  - Arbitrary array of files and directories to copy into test environment
* If you specify a directory it will copy all the files to /tmp/kitchen with the directory structure
* if you specify the full file name they are copied to the top of the /tmp/kitchen folder in the server and the path is ignored.
i.e. if we have a directory data/ containing file xyz.txt
```
  additional_copy_path:
    - data/xyz.txt
```
it will copy data/xyz.txt to /tmp/kitchen/xyz.txt
* if you specify the directory without the filename it will preserve the path when copying to /tmp/kitchen.
```
  additional_copy_path:
    - data
```
it will copy data/xyz.txt to /tmp/kitchen/data/xyz.txt
NOTE: additional_copy_path does copy files that are links but if you specify the full file path only the file name is copied to /tmp/kitchen

### recursive_additional_copy_path
This copies the directories in a resursive fashion which can work better for some directory structures
* It does not support specifying files with paths. i.e. you can only specify files at the top level of the repository
```
  recursive_additional_copy_path:
  - xyz.txt
```
* It does support copying directories in a similar fashion to additional_copy_path but uses recursion to discover the files in the directory structure which can be
problematic with files with links.
```
  recursive_additional_copy_path:
    - data
```
### additional_copy_role_path
This is the same as additional_copy_path but adds the extra paths to the ANSIBLE_ROLES_PATH ansible command parameter.

### ignore_paths_from_root and ignore_extensions_from_root
During recursive_additional_copy_path or additional_copy_role_path there are 2 additional parameters.
(NOTE: These don't apply with additional_copy_path)
* ignore_paths_from_root defaults to empty array []. This causes these paths to be ignored.
* ignore_extensions_from_root defaults to an array containg ['.pyc']. This causes files with these extensions to be ignored.
as these are implemented with the 'Find.prune' command they can be problematic with file links.


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

### Per-suite Structure

It can be beneficial to keep different Ansible layouts for different suites. Rather than having to specify the roles, modules, etc for each suite, you can create the following directory structure and they will automatically be found:

```
$kitchen_root/ansible/$suite_name/roles
$kitchen_root/ansible/$suite_name/modules
$kitchen_root/ansible/$suite_name/Ansiblefile
```

Multiple Line Structure
```yaml
provisioner::
  command: |
    sudo -s <<SERVERSPEC
    cd /opt/gdc/serverspec-core
    export SERVERSPEC_ENV=$EC2DATA_ENVIRONMENT
    export SERVERSPEC_BACKEND=exec
    serverspec junit=true tag=~skip_in_kitchen check:role:$EC2DATA_TYPE
    SERVERSPEC
```
