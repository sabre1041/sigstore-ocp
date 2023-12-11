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
kubectl apply --server-side=true --force-conflicts -f argocd/config/argocd.yaml
```

The deployment of RHTAS requires elevated permissions on the target cluster. A default policy that configures the default instance of OpenShift with elevated permissions can be applied by applying executing the following command:

```shell
kubectl apply -f argocd/rbac/clusterrolebinding.yaml
```

3. Create the Argo CD Applications

The Argo CD Applications are located in the [argocd/apps](argocd/apps) directory. Feel free to modify them as necessary so that they refer to the appropriate Git repository/branch and directory.

Execute the following command to create the Argo CD Applications:

```shell
kubectl apply -f argocd/apps
```

RHTAS will now be deployed and available shortly.

