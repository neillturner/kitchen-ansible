# encoding: utf-8

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'kitchen-ansible/version'

Gem::Specification.new do |s|
  s.name          = 'kitchen-ansible'
  s.license       = 'Apache-2.0'
  s.version       = Kitchen::Ansible::VERSION
  s.authors       = ['Neill Turner']
  s.email         = ['neillwturner@gmail.com']
  s.homepage      = 'https://github.com/neillturner/kitchen-ansible'
  s.summary       = 'ansible provisioner for test-kitchen'
  candidates = Dir.glob('{lib}/**/*') +  ['README.md', 'provisioner_options.md', 'kitchen-ansible.gemspec']
  s.files = candidates.sort
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'
  s.description = <<-EOF
== DESCRIPTION:

Ansible Provisioner for Test Kitchen

== FEATURES:

Supports running ansible-playbook

EOF
  s.add_runtime_dependency 'test-kitchen', '~> 1.4'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'rake'
  s.add_runtime_dependency 'librarian-ansible'
end
