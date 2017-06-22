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
$etcd_cmd role grant calico-cni -readwrite -path '/calico*'
$etcd_cmd user grant calico-cni -roles calico-cni

$etcd_cmd user add calico-k8s-policy:notGoodPw
$etcd_cmd role add calico-k8s-policy
$etcd_cmd role grant calico-k8s-policy -readwrite -path '/calico*'
$etcd_cmd user grant calico-k8s-policy -roles calico-k8s-policy

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
