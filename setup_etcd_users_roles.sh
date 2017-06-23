#!/bin/bash
set -e

etcd_cmd='etcdctl --endpoints https://172.18.18.101:2379 --ca-file tls-setup/certs/ca.pem --cert-file tls-setup/certs/root.pem --key-file tls-setup/certs/root-key.pem'
etcd3_cmd='etcdctl --endpoints https://172.18.18.101:2379 --cacert tls-setup/certs/ca.pem --cert tls-setup/certs/root.pem --key tls-setup/certs/root-key.pem'

$etcd_cmd user add root:notGoodPw

$etcd_cmd role add guest
$etcd_cmd role revoke guest -readwrite -path '/*'

$etcd_cmd user add calico:notGoodPw
$etcd_cmd role add calico
$etcd_cmd role grant calico -readwrite -path '/calico*'
$etcd_cmd user grant calico -roles calico

$etcd_cmd user add calico-cni:notGoodPw
$etcd_cmd role add calico-cni
$etcd_cmd role grant calico-cni -read -path '/calico/v1/ipam*'
$etcd_cmd role grant calico-cni -readwrite -path '/calico/v1/host*'
$etcd_cmd role grant calico-cni -readwrite -path '/calico/v1/policy*'
$etcd_cmd role grant calico-cni -readwrite -path '/calico/ipam/v2*'
$etcd_cmd user grant calico-cni -roles calico-cni

$etcd_cmd user add calico-k8s-policy:notGoodPw
$etcd_cmd role add calico-k8s-policy
$etcd_cmd role grant calico-k8s-policy -readwrite -path '/calico/v1/host*'
$etcd_cmd role grant calico-k8s-policy -readwrite -path '/calico/v1/policy*'
$etcd_cmd user grant calico-k8s-policy -roles calico-k8s-policy

$etcd_cmd user add calico-node:notGoodPw
$etcd_cmd role add calico-node
$etcd_cmd role grant calico-node -readwrite -path '/calico/v1*'
$etcd_cmd role grant calico-node -readwrite -path '/calico/felix/v1*'
$etcd_cmd role grant calico-node -readwrite -path '/calico/v1/ipam*'
$etcd_cmd role grant calico-node -readwrite -path '/calico/ipam/v2*'
$etcd_cmd role grant calico-node -readwrite -path '/calico/bgp/v1*'
$etcd_cmd user grant calico-node -roles calico-node

# Only used if kubernetes has `--storage-backend etcd2` on the apiserver
$etcd_cmd user add kubetcd:notGoodPw
$etcd_cmd role add kubetcd
$etcd_cmd role grant kubetcd -readwrite -path '/registry*'
$etcd_cmd user grant kubetcd -roles kubetcd

$etcd_cmd user add testUser:notGoodPw
$etcd_cmd role add testRole
$etcd_cmd role grant testRole -readwrite -path '/test*'
$etcd_cmd user grant testUser -roles testRole

export ETCDCTL_API=3
$etcd3_cmd user add root:notGoodPw

$etcd3_cmd role add guest

$etcd3_cmd user add kubetcd:notGoodPw
$etcd3_cmd role add kubetcd
$etcd3_cmd role grant-permission kubetcd --prefix=true readwrite /registry
$etcd3_cmd user grant-role kubetcd kubetcd

$etcd3_cmd user add testUser:notGoodPw
$etcd3_cmd role add testRole
$etcd3_cmd role grant-permission testRole --prefix=true readwrite /test
$etcd3_cmd role grant-permission testRole --prefix=true readwrite test
$etcd3_cmd user grant-role testUser testRole

$etcd3_cmd auth enable
unset ETCDCTL_API
# Need both enables, only doing the etcd v3 does not lock down the v2
$etcd_cmd auth enable
