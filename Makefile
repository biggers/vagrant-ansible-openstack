TOP := $(dir $(lastword $(MAKEFILE_LIST)))

all: up provision
CWD = ${PWD}

# s/sudo/become/ in Ansible 2.x
AS_EXTRA_VARS = 'remote_user=vagrant user=vagrant sudo=yes become=true become_user=vagrant become_method=sudo NOVA_VIRT_TYPE=kvm openstack_version=newton serial=1'

LIMIT = "all"

INVENTORY = ${CWD}/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory

all: up bootstrap
	sudo ls && echo "libvirt - vagrant up"
	vagrant up

# ================================================================

stop_apt:	
	ansible -i ${INVENTORY} controller,network,compute1,compute2 -m shell -a "sudo pkill -f aptitude"

bootstrap:
	sudo ls && echo "libvirt - nodes bootstrap"
	script -c "ansible-playbook --limit=${LIMIT} -i ${INVENTORY} -e ${AS_EXTRA_VARS} --sudo -v playbook.yml" boots_$$$$.log

#--inventory-file=/home/mabigger/openstack/vagrant-ansible-openstack/.vagrant/provisioners/ansible/inventory --extra-vars="{\"ansible_ssh_user\":\"vagrant\",\"NOVA_VIRT_TYPE\":\"kvm\",\"openstack_version\":\"newton\"}" --sudo -v playbook.yml

# make provision_node LIMIT=controller   # runs 'controller.yml' Playbook
provision_node:
	sudo ls && echo "libvirt - Ansible provision of group ${LIMIT}"
	script -c "ansible-playbook --limit=${LIMIT} -i ${INVENTORY} -e ${AS_EXTRA_VARS} --sudo -v ${LIMIT}.yml" ${LIMIT}_play_$$$$.log


# ================================================================

vg_provision:
	sudo ls && echo "ready to do libvirt work!"
	@vagrant provision controller
	script -c "vagrant provision --provision-with ${LIMIT}" ${LIMIT}_play_$$$$.log

demo:
	ansible-playbook -i demo/inventory demo/playbook.yml

destroy:
	vagrant destroy -f

rebuild: destroy all

.PHONY: all up provision demo
