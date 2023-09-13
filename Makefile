SHELL := /bin/bash
NODES = 1 2 3

##@ Install
install-dependency:
	sudo snap install multipass

##@ VMs

launch-vms:  ## Launch multiple virtual machines for later used.
	for number in ${NODES} ; do \
		multipass launch -c 4 -m 8G -d 30G jammy -n node-$$number ; \
	done

.PHONY: install launch-vms

##@ microk8s

deploy-microk8s:  ## Deploy microk8s on vms
	for number in ${NODES} ; do \
		multipass exec node-$$number -- sudo snap install microk8s --channel 1.28/stable --classic; \
	done
	for number in ${NODES} ; do \
		multipass exec node-$$number -- sudo microk8s status --wait-ready ; \
	done
	for number in ${NODES} ; do \
		if [ $$number != 1 ]; then \
			join_cmd=$$(multipass exec node-1 -- sudo microk8s add-node | grep "microk8s join" | head -n 1) ; \
			multipass exec node-$$number -- sudo $$join_cmd ; \
		fi \
	done
	multipass exec node-1 -- sudo microk8s kubectl get no


microk8s-enable-ceph:  ## Enable rook-ceph addon
	multipass exec node-1 -- sudo microk8s enable rook-ceph
	multipass exec node-1 -- sudo microk8s connect-external-ceph


.PHONY: deploy-microk8s microk8s-enable-ceph

##@ Ceph

deploy-microceph:  ## Deploy microceph on vms
	# snap install microceph
	for number in ${NODES} ; do \
		multipass exec node-$$number -- sudo snap install microceph --channel latest/edge ; \
	done

	# Bootstrap & add nodes to cluster
	multipass exec node-1 -- sudo microceph cluster bootstrap
	multipass exec node-1 -- sudo microceph cluster list
	for number in ${NODES} ; do \
		if [ $$number != 1 ]; then \
			token=$$(multipass exec node-1 -- sudo microceph cluster add node-$$number) ; \
			multipass exec node-$$number -- sudo microceph cluster join $$token ; \
		fi \
	done
	multipass exec node-1 -- sudo microceph cluster list

	# Add OSDs
	for number in ${NODES} ; do \
		multipass exec node-$$number -- bash -c \
			'for l in a b c; do \
				loop_file="$$(sudo mktemp -p /mnt XXXX.img)" ; \
				sudo truncate -s 1G "$${loop_file}" ; \
				loop_dev="$$(sudo losetup --show -f "$${loop_file}")" ; \
				minor="$${loop_dev##/dev/loop}" ; \
				sudo mknod -m 0660 "/dev/sdi$${l}" b 7 "$${minor}" ; \
				sudo microceph disk add --wipe "/dev/sdi$${l}" ; \
			done' ; \
	done
	# Show status
	multipass exec node-1 -- bash -c  \
		'sudo microceph status ; \
		sudo microceph.ceph status ; \
		sudo microceph disk list ; \
		'


ceph-status:  ## Show ceph status
	multipass exec node-1 -- bash -c  \
		'sudo microceph status ; \
		sudo microceph.ceph status ; \
		sudo microceph disk list ; \
		'

.PHONY: deploy-microceph ceph-status


##@ Help

.PHONY: help

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
