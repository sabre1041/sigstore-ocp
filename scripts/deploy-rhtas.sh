#!/bin/bash

SCRIPT_BASE_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

export OPENSHIFT_APPS_DOMAIN=""
export GITOPS_NAMESPACE="openshift-gitops"

export REPOSITORY_URL="https://github.com/sabre1041/sigstore-ocp.git"
export REPOSITORY_BRANCH="declarative"
export REPOSITORY_PATH="kustomize/overlays/standard"
OC_TOOL="oc"
EXTRA_ARGS=""

function display_help {
  echo "./$(basename "$0") [ -a | --apps-domain APPS_DOMAIN ] [ -b | --branch BRANCH ] [ -gn | --gitops-namespace NAMESPACE ] [ -h | --help ] [ -r | --repository REPOSITORY ] [ -t | --tool TOOL ] [ -s | --spiffe ] [ -i | --insecure ]

Deployment of Argo CD Assets to deploy Red Hat Trusted Artifact Signer (RHTAS)

Where:
  -a  | --apps-domain       OpenShift 'apps' domain
  -b  | --branch            Branch of the repository containing the source content. Defaults to '${REPOSITORY_BRANCH}'
  -gn | --gitops-namespace  Namespace where Argo CD Applications will be installed within. Defaults to '${GITOPS_NAMESPACE}'
  -i  | --insecure          Configure RHTAS to leverage default cluster generated certificates
  -h  | --help              Display this help text
  -p  | --path              Path within the repository containing the Kustomize manifests. Defaults to '${REPOSITORY_PATH}'
  -r  | --repository        Repository containing the source content. Defaults to '${REPOSITORY_URL}'
  -s  | --spiffe            Enable SPIFFE Integration
  -t  | --tool              Tool for communicating with OpenShift cluster. Defaults to '${OC_TOOL}'

"
}


for i in "${@}"
do
case $i in
    -a | --apps-domain )
    shift
    OPENSHIFT_APPS_DOMAIN="${1}"
    shift
    ;;
    -b | --branch )
    shift
    REPOSITORY_BRANCH="${1}"
    shift
    ;;
    -gn | --gitops-namespace )
    GITOPS_NAMESPACE="${1}"
    shift
    ;;
    -i | --insecure )
    REPOSITORY_PATH="kustomize/overlays/standard-insecure"
    shift
    ;;
    -p | --path )
    shift
    REPOSITORY_PATH="${1}"
    shift
    ;;
    -r | --repository )
    shift
    REPOSITORY_URL="${1}"
    shift
    ;;
    -s | --spiffe )
    EXTRA_ARGS+="--set rhtas.spiffe.enabled=true"
    shift
    ;;
    -t | --tool )
    OC_TOOL="${1}"
    shift
    ;;
    -h | --help )
    display_help
    exit 0
    ;;
    -*) echo >&2 "Invalid option: " "${@}"
    exit 1
    ;;
esac
done

# Check if helm is installed
command -v helm >/dev/null 2>&1 || { echo >&2 "helm is required but not installed.  Aborting."; exit 1; }

# Check if oc or compatible is installed
command -v ${OC_TOOL} >/dev/null 2>&1 || { echo >&2 "OpenShift or CLI tool is required but not installed.  Aborting."; exit 1; } 

# Check that User can return Argo CD Applications
${OC_TOOL} get applications.argoproj.io -n ${GITOPS_NAMESPACE} >/dev/null 2>&1

if [[ $? -ne 0 ]]; then
    echo "Failed to query Argo CD Application in the '${GITOPS_NAMESPACE}' namespace."
    exit 1
fi

# Check if OpenShift GitOps is installed
${OC_TOOL} get crd applications.argoproj.io  >/dev/null 2>&1 || { echo >&2 "Argo CD Required CRD's are not available. Ensure OpenShift GitOps has been installed.  Aborting."; exit 1; } 

if [[ -z "${OPENSHIFT_APPS_DOMAIN}" ]]; then
  OPENSHIFT_APPS_DOMAIN=$(${OC_TOOL} get cm -n openshift-config-managed  console-public -o go-template="{{ .data.consoleURL }}" | sed 's@https://@@; s/^[^.]*\.//')
fi

# Install RHTAS GitOps Chart
helm template \
  -n ${GITOPS_NAMESPACE} \
  ${SCRIPT_BASE_DIR}/../charts/trusted-artifact-signer-gitops \
  --set appsSubdomain=${OPENSHIFT_APPS_DOMAIN} \
  --set gitops.source.url=${REPOSITORY_URL} \
  --set gitops.source.branch=${REPOSITORY_BRANCH} \
  --set gitops.source.path=${REPOSITORY_PATH} ${EXTRA_ARGS} \
  | ${OC_TOOL} apply -f-

if [[ $? -ne 0 ]]; then
    echo "Failed to create RHTAS Application."
    exit 1
fi

echo
echo "RHTAS GitOps Deployment Complete!"
echo