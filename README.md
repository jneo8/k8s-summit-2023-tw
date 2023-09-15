# Deploy microk8s + microceph in multiple nodes

## Purpose

This document show how to deploy microk8s cluster which integrate with microceph cluster as a external ceph StorageClass.

## Requirement

- multipass

## Quick deploy

```sh
make launch-vms
make deploy-microk8s
make deploy-microceph
make microk8s-enable-ceph

make deploy-stateful-set
```


## Integration between microk8s and microceph

![](./attachments/microk8s-with-microceph.png)

When we enable the rook-ceph addons, which is a core-plugin in microk8s, actually we use helm in the backend to install the rook on ceph-rook namespace.

> See [microk8s-core-addons](https://github.com/canonical/microk8s-core-addons/tree/main/addons/rook-ceph) for more details.

Then we use the [plugin script](https://github.com/canonical/microk8s-core-addons/blob/main/addons/rook-ceph/plugin/connect-external-ceph), which will auto-detect the local's microceph, to define a [CephCluster CRD](https://rook.io/docs/rook/v1.12/CRDs/Cluster/ceph-cluster-crd/), which connects to external ceph(microceph) and run a series of operation action to import secret, import user, and create storage class.


## Microceph Architecture

![](./attachments/microceph-architecture.png)

The microceph snap packages all the required ceph-binaries, [dqlite](https://dqlite.io/) and a small management daemon (microcephd) which ties all of this together. Using the light-weight distributed dqlite layer, MicroCeph enables orchestration of a ceph cluster in a centralised and easy to use manner.

> See [HACKING.md](https://github.com/canonical/microceph/blob/main/HACKING.md) for more details.

