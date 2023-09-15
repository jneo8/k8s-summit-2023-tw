# Microk8s architecture

## Projects

- [microk8s](https://github.com/canonical/microk8s)
- [kubernetes-dqlite](https://github.com/canonical/kubernetes-dqlite)
- [k8s-dqlite](https://github.com/canonical/k8s-dqlite)
- [microk8s-cluster-agent](https://github.com/canonical/microk8s-cluster-agent)
- [microk8s-core-addons](https://github.com/canonical/microk8s-core-addons)
- [microk8s-community-addons](https://github.com/canonical/microk8s-community-addons)


## Refenences

- https://microk8s.io/docs/configuring-services
- https://microk8s.io/docs/services-and-ports


## Default services when install microk8s


```
microk8s.daemon-apiserver-kicker  enabled  active    -
microk8s.daemon-apiserver-proxy   enabled  inactive  -
microk8s.daemon-cluster-agent     enabled  active    -
microk8s.daemon-containerd        enabled  active    -
microk8s.daemon-etcd              enabled  inactive  -
microk8s.daemon-flanneld          enabled  inactive  -
microk8s.daemon-k8s-dqlite        enabled  active    -
microk8s.daemon-kubelite          enabled  active    -
```
