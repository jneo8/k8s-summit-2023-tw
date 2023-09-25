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

## Trace into code

```sh
git clone https://github.com/canonical/kubernetes-dqlite.git
cd kubernetes-dqlite
git remote add upstream https://github.com/kubernetes/kubernetes.git

git list-remote origin | grep release
git list-remote upstream | grep release

git diff upstream/release-1.22 origin/release-1.22 --stat
git diff upstream/release-1.22 origin/release-1.22 --patch-with-stat
```

### cmd/kube-apiserver

Run kvsqlserver when start the apiserver.

- **EtcdOptions.AddFlags**
    - https://github.com/kubernetes/apiserver/blob/a02dbeed8d6e0b601f518d2c007482e08ed5c36b/pkg/server/options/etcd.go#L114
- **NewAPIServerCommand, Run function**
    - https://github.com/canonical/kubernetes-dqlite/blob/36a416b4464c9aec30bc47737a7f5e6301cc9f04/cmd/kube-apiserver/app/server.go#L174


```git
 cmd/kube-apiserver/app/aggregator.go           |  9 +++---
 cmd/kube-apiserver/app/options/options.go      | 11 ++-----
 cmd/kube-apiserver/app/options/options_test.go |  5 ++-
 cmd/kube-apiserver/app/server.go               | 44 ++++++++++++++++++++++++--
 4 files changed, 50 insertions(+), 19 deletions(-)

diff --git a/cmd/kube-apiserver/app/aggregator.go b/cmd/kube-apiserver/app/aggregator.go
index 1ec89a0e8bc..ce90f4080f7 100644
--- a/cmd/kube-apiserver/app/aggregator.go
+++ b/cmd/kube-apiserver/app/aggregator.go
@@ -110,11 +110,10 @@ func createAggregatorConfig(
 			SharedInformerFactory: externalInformers,
 		},
 		ExtraConfig: aggregatorapiserver.ExtraConfig{
-			ProxyClientCertFile:       commandOptions.ProxyClientCertFile,
-			ProxyClientKeyFile:        commandOptions.ProxyClientKeyFile,
-			ServiceResolver:           serviceResolver,
-			ProxyTransport:            proxyTransport,
-			RejectForwardingRedirects: commandOptions.AggregatorRejectForwardingRedirects,
+			ProxyClientCertFile: commandOptions.ProxyClientCertFile,
+			ProxyClientKeyFile:  commandOptions.ProxyClientKeyFile,
+			ServiceResolver:     serviceResolver,
+			ProxyTransport:      proxyTransport,
 		},
 	}
 
diff --git a/cmd/kube-apiserver/app/options/options.go b/cmd/kube-apiserver/app/options/options.go
index 75970f42546..50955821973 100644
--- a/cmd/kube-apiserver/app/options/options.go
+++ b/cmd/kube-apiserver/app/options/options.go
@@ -80,8 +80,7 @@ type ServerRunOptions struct {
 	ProxyClientCertFile string
 	ProxyClientKeyFile  string
 
-	EnableAggregatorRouting             bool
-	AggregatorRejectForwardingRedirects bool
+	EnableAggregatorRouting bool
 
 	MasterCount            int
 	EndpointReconcilerType string
@@ -137,8 +136,7 @@ func NewServerRunOptions() *ServerRunOptions {
 			},
 			HTTPTimeout: time.Duration(5) * time.Second,
 		},
-		ServiceNodePortRange:                kubeoptions.DefaultServiceNodePortRange,
-		AggregatorRejectForwardingRedirects: true,
+		ServiceNodePortRange: kubeoptions.DefaultServiceNodePortRange,
 	}
 
 	// Overwrite the default for storage data format.
@@ -171,7 +169,7 @@ func addDummyInsecureFlags(fs *pflag.FlagSet) {
 func (s *ServerRunOptions) Flags() (fss cliflag.NamedFlagSets) {
 	// Add the generic flags.
 	s.GenericServerRunOptions.AddUniversalFlags(fss.FlagSet("generic"))
-	s.Etcd.AddFlags(fss.FlagSet("etcd"))
+	s.Etcd.AddFlags(fss.FlagSet("storage"))
 	s.SecureServing.AddFlags(fss.FlagSet("secure serving"))
 	addDummyInsecureFlags(fss.FlagSet("insecure serving"))
 	s.Audit.AddFlags(fss.FlagSet("auditing"))
@@ -270,9 +268,6 @@ func (s *ServerRunOptions) Flags() (fss cliflag.NamedFlagSets) {
 	fs.BoolVar(&s.EnableAggregatorRouting, "enable-aggregator-routing", s.EnableAggregatorRouting,
 		"Turns on aggregator routing requests to endpoints IP rather than cluster IP.")
 
-	fs.BoolVar(&s.AggregatorRejectForwardingRedirects, "aggregator-reject-forwarding-redirect", s.AggregatorRejectForwardingRedirects,
-		"Aggregator reject forwarding redirect response back to client.")
-
 	fs.StringVar(&s.ServiceAccountSigningKeyFile, "service-account-signing-key-file", s.ServiceAccountSigningKeyFile, ""+
 		"Path to the file that contains the current private key of the service account token issuer. The issuer will sign issued ID tokens with this private key.")
 
diff --git a/cmd/kube-apiserver/app/options/options_test.go b/cmd/kube-apiserver/app/options/options_test.go
index bca6acabc63..912285fd4bf 100644
--- a/cmd/kube-apiserver/app/options/options_test.go
+++ b/cmd/kube-apiserver/app/options/options_test.go
@@ -314,9 +314,8 @@ func TestAddFlags(t *testing.T) {
 		Traces: &apiserveroptions.TracingOptions{
 			ConfigFile: "/var/run/kubernetes/tracing_config.yaml",
 		},
-		IdentityLeaseDurationSeconds:        3600,
-		IdentityLeaseRenewIntervalSeconds:   10,
-		AggregatorRejectForwardingRedirects: true,
+		IdentityLeaseDurationSeconds:      3600,
+		IdentityLeaseRenewIntervalSeconds: 10,
 	}
 
 	if !reflect.DeepEqual(expected, s) {
diff --git a/cmd/kube-apiserver/app/server.go b/cmd/kube-apiserver/app/server.go
index 8b23c685fc8..bd4aee5765e 100644
--- a/cmd/kube-apiserver/app/server.go
+++ b/cmd/kube-apiserver/app/server.go
@@ -20,6 +20,7 @@ limitations under the License.
 package app
 
 import (
+	"context"
 	"crypto/tls"
 	"fmt"
 	"net"
@@ -32,10 +33,13 @@ import (
 	"github.com/spf13/cobra"
 	"github.com/spf13/pflag"
 
+	kvsqlfactory "github.com/canonical/kvsql-dqlite"
+	kvsqlserver "github.com/canonical/kvsql-dqlite/server"
 	extensionsapiserver "k8s.io/apiextensions-apiserver/pkg/apiserver"
 	utilerrors "k8s.io/apimachinery/pkg/util/errors"
 	utilnet "k8s.io/apimachinery/pkg/util/net"
 	"k8s.io/apimachinery/pkg/util/sets"
+	utilwait "k8s.io/apimachinery/pkg/util/wait"
 	"k8s.io/apiserver/pkg/admission"
 	"k8s.io/apiserver/pkg/authorization/authorizer"
 	openapinamer "k8s.io/apiserver/pkg/endpoints/openapi"
@@ -45,6 +49,8 @@ import (
 	"k8s.io/apiserver/pkg/server/filters"
 	serveroptions "k8s.io/apiserver/pkg/server/options"
 	serverstorage "k8s.io/apiserver/pkg/server/storage"
+	"k8s.io/apiserver/pkg/storage/etcd3/preflight"
+	"k8s.io/apiserver/pkg/storage/storagebackend"
 	utilfeature "k8s.io/apiserver/pkg/util/feature"
 	utilflowcontrol "k8s.io/apiserver/pkg/util/flowcontrol"
 	"k8s.io/apiserver/pkg/util/webhook"
@@ -76,6 +82,11 @@ import (
 	"k8s.io/kubernetes/pkg/serviceaccount"
 )
 
+const (
+	etcdRetryLimit    = 60
+	etcdRetryInterval = 1 * time.Second
+)
+
 // TODO: delete this check after insecure flags removed in v1.24
 func checkNonZeroInsecurePort(fs *pflag.FlagSet) error {
 	for _, name := range options.InsecurePortFlags {
@@ -91,7 +102,7 @@ func checkNonZeroInsecurePort(fs *pflag.FlagSet) error {
 }
 
 // NewAPIServerCommand creates a *cobra.Command object with default parameters
-func NewAPIServerCommand() *cobra.Command {
+func NewAPIServerCommand(stopCh... <- chan struct{}) *cobra.Command {
 	s := options.NewServerRunOptions()
 	cmd := &cobra.Command{
 		Use: "kube-apiserver",
@@ -127,8 +138,11 @@ cluster's shared state through which all other components interact.`,
 			if errs := completedOptions.Validate(); len(errs) != 0 {
 				return utilerrors.NewAggregate(errs)
 			}
-
-			return Run(completedOptions, genericapiserver.SetupSignalHandler())
+			if len(stopCh) != 0 {
+				return Run(completedOptions, stopCh[0])
+			} else {
+				return Run(completedOptions, genericapiserver.SetupSignalHandler())
+			}
 		},
 		Args: func(cmd *cobra.Command, args []string) error {
 			for _, arg := range args {
@@ -157,6 +171,17 @@ cluster's shared state through which all other components interact.`,
 
 // Run runs the specified APIServer.  This should never exit.
 func Run(completeOptions completedServerRunOptions, stopCh <-chan struct{}) error {
+	if completeOptions.Etcd.StorageConfig.Type == storagebackend.StorageTypeDqlite {
+		config := completeOptions.Etcd.StorageConfig
+		server, err := kvsqlserver.New(config.Dir)
+		if err != nil {
+			return err
+		}
+		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
+		defer cancel()
+		defer server.Close(ctx)
+	}
+
 	// To help debugging, immediately log version
 	klog.Infof("Version: %+v", version.Get())
 
@@ -196,6 +221,11 @@ func CreateServerChain(completedOptions completedServerRunOptions, stopCh <-chan
 		return nil, err
 	}
 
+	if completedOptions.Etcd.StorageConfig.Type == storagebackend.StorageTypeDqlite {
+		kvsqlRoutes := kvsqlfactory.Rest{}
+		kvsqlRoutes.Install(kubeAPIServer.GenericAPIServer.Handler.GoRestfulContainer)
+	}
+
 	// aggregator comes last in the chain
 	aggregatorConfig, err := createAggregatorConfig(*kubeAPIServerConfig.GenericConfig, completedOptions.ServerRunOptions, kubeAPIServerConfig.ExtraConfig.VersionedInformers, serviceResolver, kubeAPIServerConfig.ExtraConfig.ProxyTransport, pluginInitializer)
 	if err != nil {
@@ -246,6 +276,14 @@ func CreateKubeAPIServerConfig(s completedServerRunOptions) (
 		return nil, nil, nil, err
 	}
 
+	if s.Etcd.StorageConfig.Type != storagebackend.StorageTypeDqlite {
+		if _, port, err := net.SplitHostPort(s.Etcd.StorageConfig.Transport.ServerList[0]); err == nil && port != "0" && len(port) != 0 {
+			if err := utilwait.PollImmediate(etcdRetryInterval, etcdRetryLimit*etcdRetryInterval, preflight.EtcdConnection{ServerList: s.Etcd.StorageConfig.Transport.ServerList}.CheckEtcdServers); err != nil {
+				return nil, nil, nil, fmt.Errorf("error waiting for etcd connection: %v", err)
+			}
+		}
+	}
+
 	capabilities.Initialize(capabilities.Capabilities{
 		AllowPrivileged: s.AllowPrivileged,
 		// TODO(vmarmol): Implement support for HostNetworkSources.
```