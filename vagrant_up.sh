#!/bin/bash

kube_ver=v1.7.0-beta.1

SKIP_SERVICE_CHECK=no

if [ ! -f kubectl ]; then
    wget http://storage.googleapis.com/kubernetes-release/release/$kube_ver/bin/linux/amd64/kubectl
    chmod +x kubectl
fi
export PATH=./:$PATH

vagrant up
if [ $? -ne 0 ]; then
    echo "Vagrant returned non-zero rc"
    exit 1
fi

hosts=""
for ((n=1;n<=$MASTERS;n++)); do hosts="$hosts k8s-master-0$n"; done
for ((n=1;n<=$NODES;n++)); do hosts="$hosts k8s-node-0$n"; done
host_count=$(($MASTERS+$NODES))

wait_for_pods_running()
{
    while [ $(kubectl get pods --all-namespaces | grep -c -v "$1") -eq 0 ]; do
        echo "Waiting for $1 pods to be starting"
		sleep 10
    done
	while [ $(kubectl get pods --all-namespaces | tail -n +2 | grep -c -v Running) -ne 0 ]; do
	    echo "Waiting for all pods to be running"
	    kubectl get pods -n kube-system | grep -v Running
		sleep 2
	done
}

etcd_test_cmd='etcdctl --endpoints https://172.18.18.101:2379 --ca-file tls-setup/certs/ca.pem --cert-file tls-setup/certs/test.pem --key-file tls-setup/certs/test-key.pem'
etcd3_test_cmd='etcdctl --endpoints https://172.18.18.101:2379 --cacert tls-setup/certs/ca.pem --cert tls-setup/certs/test.pem --key tls-setup/certs/test-key.pem'
etcd_calico_cmd='etcdctl --endpoints https://172.18.18.101:2379 --ca-file tls-setup/certs/ca.pem --cert-file tls-setup/certs/calico.pem --key-file tls-setup/certs/calico-key.pem'
etcd3_k8s_cmd='etcdctl --endpoints https://172.18.18.101:2379 --cacert tls-setup/certs/ca.pem --cert tls-setup/certs/kubernetes.pem --key tls-setup/certs/kubernetes-key.pem'
etcd_blah_cmd='etcdctl --endpoints https://172.18.18.101:2379 --ca-file tls-setup/certs/ca.pem --cert-file tls-setup/certs/blah.pem --key-file tls-setup/certs/blah-key.pem'
etcd3_blah_cmd='etcdctl --endpoints https://172.18.18.101:2379 --cacert tls-setup/certs/ca.pem --cert tls-setup/certs/blah.pem --key tls-setup/certs/blah-key.pem'
check_etcd_perms()
{
    echo "==Check Test user can't access /calico"
    $etcd_test_cmd ls /calico
    if [ $? -eq 0 ]; then echo "Test user could access /calico when it should not have"; exit 1; fi
    echo "==Check Calico user can access /calico"
    $etcd_calico_cmd ls /calico
    echo "==Check Blah user can't access /calico"
    if [ $? -ne 0 ]; then echo "Calico user could not access /calico when it should have"; exit 1; fi
    $etcd_blah_cmd ls /calico
    if [ $? -eq 0 ]; then echo "Unknown user could access /calico when it should not have"; exit 1; fi
    export ETCDCTL_API=3
    echo "==Check test user can't access (v3)/registry"
    $etcd3_test_cmd get /registry
    if [ $? -eq 0 ]; then echo "Test user could access /registry when it should not have"; exit 1; fi
    echo "==Check kubernetes user can access (v3)/registry"
    $etcd3_k8s_cmd get /registry
    if [ $? -ne 0 ]; then echo "K8s user could not access /registry when it should have"; exit 1; fi
    echo "==Check Blah user can't access (v3)/registry"
    $etcd3_blah_cmd get /registry
    if [ $? -eq 0 ]; then echo "Blah user could access /registry when it should not have"; exit 1; fi
    unset ETCDCTL_API
}

if [ $SKIP_SERVICE_CHECK == "no" ]; then
for x in $hosts; do
    jobs="$(vagrant ssh $x -c 'sudo systemctl status | grep [J]obs:')"
    ojobs=""
    while [ $(echo $jobs | grep -c '0 queued') -ne 1 ]; do
        if [ "$jobs" != "$jobs" ]; then
            echo "$x: Waiting for inital services to be up: $jobs"
        else
            echo -n '.'
        fi
        ojobs="$jobs"
        sleep 2
        jobs="$(vagrant ssh $x -c 'sudo systemctl status | grep [J]obs:' 2>/dev/null)"
    done
    failed="$(vagrant ssh $x -c 'sudo systemctl status | grep [F]ailed:')"
    if [ $(echo $failed | grep -c '0 units') -ne 1 ]; then
        echo "Failure from $x, showed:"
        echo "$failed"
        exit 1
    fi
done
fi

for x in $hosts; do
    vagrant ssh $x -c 'ping -c 3 172.18.18.102 && ping -c 3 172.18.18.101'
    if [ $? -ne 0 ]; then echo "Failed pings from $x"; exit 1; fi
    vagrant ssh $x -c 'curl -L http://172.18.18.101:2379/version'
    if [ $? -ne 0 ]; then echo "Failed to curl etcd $x"; exit 1; fi
    vagrant ssh $x -c 'sudo docker ps'
    if [ $? -ne 0 ]; then echo "Docker not happy on $x"; exit 1; fi
done

./setup_etcd_users_roles.sh

kubectl config set-cluster vagrant-cluster --server=http://172.18.18.101:8080
kubectl config set-context vagrant-system --cluster=vagrant-cluster
kubectl config use-context vagrant-system

while [ $(kubectl get nodes | tail -n +2 | wc -l) -ne $host_count ]; do
	sleep 5
	echo 'Waiting for nodes to work'
done

kubectl apply -f k8s/calico.yaml
if [ $? -ne 0 ]; then echo "kubectl apply calico was not happy"; exit 1; fi

echo "Waiting for calico-node to be running"
wait_for_pods_running calico-node

kubectl apply -f k8s/skydns.yaml
if [ $? -ne 0 ]; then echo "kubectl apply was not happy"; exit 1; fi

echo "Waiting for skydns pod to be running"
wait_for_pods_running kube-dns

check_etcd_perms

kubectl run nginx --replicas=2 --image=nginx
kubectl expose deployment nginx --port=80
echo "kubectl run access --rm -ti --image busybox /bin/sh"
