# Declarative Configuration of Red Hat Trusted Artifact Signer (RHTAS)

## Argo CD / OpenShift GitOps Configuration


1. Deploy OpenShift GitOps

Execute the following command to deploy OpenShift GitOps

```shell
kubectl apply -f argocd/operator
```

Wait until the OpenShift GitOps Operator has been deployed and the `ArgoCD` Custom Resource is available.

```shell
until kubectl wait crd/argocds.argoproj.io --for condition=established &>/dev/null; do sleep 5; done
until kubectl get argocd -n openshift-gitops openshift-gitops &>/dev/null; do sleep 5; done
```

2. Argo CD Configuration

Configure custom Kustomize build options against the `ArgoCD` resource:

```shell
kubectl apply --server-side=true -f argocd/config/argocd.yaml
```

The deployment of RHTAS requires elevated permissions on the target cluster. A default policy that configures the default instance of OpenShift with elevated permissions can be applied by applying executing the following command:

```shell
kubectl apply -f argocd/rbac/clusterrolebinding.yaml
```

3. Create the Argo CD Applications

A series of Argo CD Applications will be created to deploy RHTAS as well as any dependencies (such as RHSSO/Keycloak).

Deploy Keycloak by executing the following command:

```shell
oc apply -f argocd/apps/keycloak-operator.yaml -f argocd/apps/keycloak.yaml
```

Finally, the Argo CD Application for RHTAS can be deployed. Execute the [scropts/deploy-rhtas.sh] script. The following parameters are available:

* `-s` - Integrate with [SPIFFE](https://spiffe.io) using the steps as described in [this repository](https://github.com/sabre1041/spiffe-openshift).
* `-i` - Configure RHTAS to trust the default cluster generated certificates
* `-a` - Specify the _apps_ subdomain (otherwise will obtain the cluster default).

Execute the script:

```shell
./scripts/deploy-rhtas.sh
```

RHTAS will now be deployed and available shortly.

