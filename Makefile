.PHONY: clean

MASTERS ?= 1
NODES ?= 2

etcd-users := calico calico-cni calico-k8s-policy calico-node

all: calico-certs
	sed -i -e "s/^num_instances=.*$$/num_instances=$$(($(NODES)+$(MASTERS)))/" Vagrantfile
	MASTERS=$(MASTERS) NODES=$(NODES) K8S_CACHED=true ./vagrant_up.sh
	./simple-policy.sh

tls-setup/certs:
	cd tls-setup; make

.PHONY: calico-certs
calico-certs: tls-setup/certs k8s/calico.yaml $(etcd-users)
	ca="$$(cat tls-setup/certs/ca.pem | base64 -w 0)"; \
	sed -i -e "s/calico-etcd-rbac-ca/$$ca/" k8s/calico.yaml

.PHONY: $(etcd-users)
$(etcd-users): k8s/calico.yaml
	cert="$$(cat tls-setup/certs/$@.pem | base64 -w 0)"; \
	sed -i -e "s/$@-etcd-rbac-cert/$$cert/" k8s/calico.yaml
	key="$$(cat tls-setup/certs/$@-key.pem | base64 -w 0)"; \
	sed -i -e "s/$@-etcd-rbac-key/$$key/" k8s/calico.yaml

k8s/calico.yaml:
	cp calico.yaml.template k8s/calico.yaml

clean:
	cd tls-setup; make clean
	rm -f k8s/calico.yaml
