#!/bin/bash

wait_for_pods_running()
{
	while [ $(kubectl get pods --all-namespaces | tail -n +2 | grep -c -v Running) -ne 0 ]; do
	    echo "Waiting for all pods to be running"
	    kubectl get pods -n kube-system | grep -v Running
		sleep 2
	done
}

check_access()
{
    name=$1
    expected=${2:-0}
    cnt=0
    while [ $cnt -lt 5 ]; do
        kubectl run --namespace=policy-demo $name --restart=Never --rm -it --image busybox -- /bin/wget -q --timeout=5 nginx -O -
        if [ $? -ne $expected ]; then echo "Accessing as $name did not match $expected"; exit 1; fi
        cnt=$((cnt+1))
    done
}

if [ $(kubectl get ns| grep -c policy-demo) -gt 0 ]; then
    kubectl delete ns policy-demo
fi

echo "Creating policy-demo namespace"
kubectl create ns policy-demo
if [ $? -ne 0 ]; then echo "kubectl create ns was not happy"; exit 1; fi

echo "Launching nginx and exposing service"
kubectl run --namespace=policy-demo nginx --replicas=2 --image=nginx
if [ $? -ne 0 ]; then echo "kubectl run nginx was not happy"; exit 1; fi
kubectl expose --namespace=policy-demo deployment nginx --port=80
if [ $? -ne 0 ]; then echo "kubectl expose nginx service was not happy"; exit 1; fi

echo "Waiting for nginx pods to be running"
wait_for_pods_running

echo "Checking that we can access without any restrictions or policy"
check_access access

echo "Setting annotation for DefaultDeny"
kubectl annotate ns policy-demo "net.beta.kubernetes.io/network-policy={\"ingress\":{\"isolation\":\"DefaultDeny\"}}"
sleep 2

check_access access 1

echo "Creating policy to allow 'access'"
kubectl create -f - <<EOF
kind: NetworkPolicy
apiVersion: extensions/v1beta1
metadata:
  name: access-nginx
  namespace: policy-demo
spec:
  podSelector:
    matchLabels:
      run: nginx
  ingress:
    - from:
      - podSelector:
          matchLabels:
            run: access
EOF

echo "Checking that we can access after policy is created"
check_access access

echo "Checking that 'cant-access' cannot access with policy"
check_access cant-access 1

echo "Removing namespace to clean up"
kubectl delete ns policy-demo
