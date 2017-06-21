.PHONY: clean

MASTERS ?= 1
NODES ?= 2

all: tls-setup/certs
	sed -i -e "s/^num_instances=.*$$/num_instances=$$(($(NODES)+$(MASTERS)))/" Vagrantfile
	MASTERS=$(MASTERS) NODES=$(NODES) K8S_CACHED=true ./vagrant_up.sh

tls-setup/certs:
	cd tls-setup; make
	# Update calico manifest
	rm -rf tmp
	mkdir -p tmp
	cat tls-setup/certs/calico.pem | base64 | sed -e 's/^/    /' tmp/calico.pem
	cat tls-setup/certs/calico-key.pem | base64 | sed -e 's/^/    /' tmp/calico-key.pem
	cat tls-setup/certs/ca.pem | base64 | sed -e 's/^/    /' tmp/ca.pem
	sed -e '/calico-etcd-rbac-key/r./tmp/calico-key.pem' calico.yaml.template > k8s/calico.yaml
	sed -i -e '/calico-etcd-rbac-cert/r./tmp/calico.pem' k8s/calico.yaml
	sed -i -e '/calico-etcd-rbac-ca/r./tmp/ca.pem' k8s/calico.yaml
	sed -i '/^ *calico-etcd-rbac-.*$$/d' k8s/calico.yaml

clean:
	cd tls-setup; make clean
