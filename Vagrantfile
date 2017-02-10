# -*-ruby-*-
#
# Copyright (c) 2015 Davide Guerri <davide.guerri@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Vagrant demo setup for Ansible-OpenStack roles
#
# Architecture
# ============
#
#    +----------------------Vagrant-Workstation----------------------+
#    |                                                               |
#    |  +---------------------------------------------------------+  |
#    |  |                Management - 10.1.2.0/24                 |  |
#    |  +---------------------------------------------------------+  |
#    |        |             |             |                 |        |
#    |        |.10          |.20          |.30              |.30+N-1 |
#    |  +-----------+ +-----------+ +-----------+     +-----------+  |
#    |  |           | |           | |           |     |           |  |
#    |  |Controller | |  Network  | | Compute1  |. . .| ComputeN  |  |
#    |  |           | |           | |           |     |           |  |
#    |  +-----------+ +-----------+ +-----------+     +-----------+  |
#    |                   |     |.5        |.6               | .6+N-1 |
#    |                   |     |          |                 |        |
#    |              +----+  +-------------------------------------+  |
#    |              |       |     Tunnels - 192.168.129.0/24      |  |
#    |              |       +-------------------------------------+  |
#    |  +----------------------------------------------+             |
#    |  |  External (Bridged to workstation network)   |             |
#    |  +----------------------------------------------+             |
#    +----------|----------------------------------------------------+
#               |                           +------+
#            +-----+                        |      +------+------+
#          +-|-----|-+                      ++                   |
#          | ||   || |-----------------------|    Internet     +-+
#          +-|-----|-+                       |                 |
#            +-----+                         +-----------+     |
#        Router (+ DHCP)                                 +-----+
#
#                     (Drawn with Monodraw alpha, courtesy of Milen Dzhumerov)
##############################################################################

COMPUTE_NODES = (ENV['COMPUTE_NODES'] || 2).to_i
VAGRANT_BOX_NAME = ENV['BOX_NAME'] || 'yk0/ubuntu-xenial' # 's3than/trusty64'
CONTROLLER_RAM = (ENV['CONTROLLER_RAM'] || 3072).to_i
NETWORK_RAM = (ENV['NETWORK_RAM'] || 1024).to_i
COMPUTE_RAM = (ENV['COMPUTE_RAM'] || 12288).to_i
NESTED_VIRT = (ENV['NESTED_VIRT'] || 'true') == 'true'
LIBVIRT_DRIVER = ENV['LIBVIRT_DRIVER'] || 'kvm'
CACHE_SCOPE = ENV['CACHE_SCOPE'] || :machine
EXTERNAL_NETWORK_IF = ENV['EXTERNAL_NETWORK_IF'] || nil

vagrant_dir = File.expand_path(File.dirname(__FILE__))

Vagrant.configure('2') do |config|

  if Vagrant.has_plugin?('vagrant-cachier')
    config.cache.auto_detect = false
    config.cache.enable :apt
    config.cache.scope = CACHE_SCOPE
  end

  config.ssh.insert_key = false

  # config.vm.synced_folder "#{vagrant_dir}", '/vagrant',
  #   :nfs => true,
  #   :nfs_version => 3,
  #   :mount_options => ['rw', 'udp', 'retry=0', 'nolock']

  config.vm.synced_folder '.', '/vagrant', disabled: true

  # Cloud controller
  config.vm.define 'controller' do |server|
    server.vm.hostname = 'controller'

    server.vm.box = VAGRANT_BOX_NAME

    # Management network (eth1)
    server.vm.network :private_network, ip: '10.1.2.10'

    %w(parallels virtualbox libvirt vmware_fusion).each do |provider|
      server.vm.provider provider do |c|
        c.memory = CONTROLLER_RAM
        c.cpus = 4

        c.driver = LIBVIRT_DRIVER if provider == 'libvirt'
      end
    end
  end

  # Network controller
  config.vm.define 'network' do |server|

    server.vm.hostname = 'network'
    server.vm.box = VAGRANT_BOX_NAME

    # Management network (eth1)
    server.vm.network :private_network, ip: '10.1.2.20'

    # Tunnels network (eth2)
    server.vm.network :private_network, ip: '192.168.129.5'

    # External network (eth3) - Mixed syntax to accomodate libvirt
    server.vm.network :private_network, ip: '192.168.101.101',
                                        mode: 'passthrough'
    # server.vm.network :public_network, mode: 'passthrough',
    #                                    dev: EXTERNAL_NETWORK_IF,
    #                                    bridge: EXTERNAL_NETWORK_IF
    # External network (eth3) - Mixed syntax to accomodate libvirt

    %w(parallels virtualbox libvirt vmware_fusion).each do |provider|
      server.vm.provider provider do |c|
        c.memory = NETWORK_RAM
        c.cpus = 1

        c.driver = LIBVIRT_DRIVER if provider == 'libvirt'
        # Enable promiscuous mode for external interface
        c.customize [
          'modifyvm', :id, '--nicpromisc4', 'allow-all'
        ] if provider == 'virtualbox'
      end
    end
  end

  # Compute nodes
  COMPUTE_NODES.times do |number|
    config.vm.define "compute#{number + 1}" do |server|

      server.vm.hostname = "compute#{number + 1}"
      server.vm.box = VAGRANT_BOX_NAME

      # Management network (eth1)
      server.vm.network :private_network, ip: "10.1.2.#{30 + number}"

      # Tunnels network (eth2)
      server.vm.network :private_network, ip: "192.168.129.#{6 + number}"

      # Provider specific settings
      %w(parallels virtualbox libvirt vmware_fusion).each do |provider|
        server.vm.provider provider do |c|
          c.memory = COMPUTE_RAM
          c.cpus = 4

          c.driver = LIBVIRT_DRIVER if provider == 'libvirt'
          if NESTED_VIRT
            c.vmx['vhv.enable'] = 'TRUE' if provider == 'vmware_fusion'
            c.nested = true if provider == 'libvirt'
            c.customize [
              'set', :id, '--nested-virt', 'on'
            ] if provider == 'parallels'
          end
        end
      end
    end
  end

  # Ansible provisioners
  config.vm.provision 'bootstrap', run: 'never', type: 'ansible' do |boots|
    boots.playbook = 'bootstrap.yml'
    boots.limit = 'all'
    boots.sudo = true
    boots.verbose = true  # for seeing the playbook-run
    boots.extra_vars = {
      'ansible_ssh_user' => 'vagrant',
      'NOVA_VIRT_TYPE' => LIBVIRT_DRIVER,
      'openstack_version' => 'newton'
    }
    boots.groups = {
      'controller' => 'controller',
      'network' => 'network',
      'compute_nodes' => COMPUTE_NODES.times.map { |x| "compute#{x + 1}" }
    }
  end

  config.vm.provision 'controller', run: 'never', type: :ansible do |nodes|
    nodes.playbook = 'YAMLs/controller.yml'
    nodes.limit = 'controller'
    nodes.sudo = true
    nodes.verbose = true
    nodes.extra_vars = {
      'ansible_ssh_user' => 'vagrant',
      'NOVA_VIRT_TYPE' => LIBVIRT_DRIVER,
      'openstack_version' => 'newton'
    }
    nodes.groups = {
      'controller' => 'controller',
      'network' => 'network',
      'compute_nodes' => COMPUTE_NODES.times.map { |x| "compute#{x + 1}" }
    }
  end

  config.vm.provision 'network', run: 'never', type: :ansible do |nodes|
    nodes.playbook = 'network.yml'
    nodes.limit = 'network'
    nodes.sudo = true
    nodes.verbose = true
    nodes.extra_vars = {
      'ansible_ssh_user' => 'vagrant',
      'NOVA_VIRT_TYPE' => LIBVIRT_DRIVER,
      'openstack_version' => 'newton'
    }
    nodes.groups = {
      'controller' => 'controller',
      'network' => 'network',
      'compute_nodes' => COMPUTE_NODES.times.map { |x| "compute#{x + 1}" }
    }
  end

  config.vm.provision 'compute', run: 'never', type: :ansible do |nodes|
    nodes.playbook = 'compute.yml'
    nodes.limit = 'compute'
    nodes.sudo = true
    nodes.verbose = true
    nodes.extra_vars = {
      'ansible_ssh_user' => 'vagrant',
      'NOVA_VIRT_TYPE' => LIBVIRT_DRIVER,
      'openstack_version' => 'newton'
    }
    nodes.groups = {
      'controller' => 'controller',
      'network' => 'network',
      'compute_nodes' => COMPUTE_NODES.times.map { |x| "compute#{x + 1}" }
    }
  end

end
