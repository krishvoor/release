#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -x
cat /etc/os-release
oc config view
oc projects
python --version
pushd /tmp
python -m virtualenv ./venv_qe
source ./venv_qe/bin/activate

ES_PASSWORD=$(cat "/secret/password")
ES_USERNAME=$(cat "/secret/username")

REPO_URL="https://github.com/cloud-bulldozer/e2e-benchmarking";
LATEST_TAG=$(curl -s "https://api.github.com/repos/cloud-bulldozer/e2e-benchmarking/releases/latest" | jq -r '.tag_name');
TAG_OPTION="--branch $(if [ "$E2E_VERSION" == "default" ]; then echo "$LATEST_TAG"; else echo "$E2E_VERSION"; fi)";
git clone https://github.com/rsevilla87/e2e-benchmarking/ -b kube-burner-ocp
pushd e2e-benchmarking/workloads/kube-burner-ocp-wrapper
export WORKLOAD=node-density-cni

# A non-indexed warmup run
ES_SERVER="" EXTRA_FLAGS="--pods-per-node=50" ./run.sh

# The measurable run
export EXTRA_FLAGS="--gc-metrics=true --pods-per-node=$PODS_PER_NODE --namespaced-iterations=$NAMESPACED_ITERATIONS --iterations-per-namespace=$ITERATIONS_PER_NAMESPACE --profile-type=${PROFILE_TYPE}"

export ES_SERVER="https://$ES_USERNAME:$ES_PASSWORD@search-ocp-qe-perf-scale-test-elk-hcm7wtsqpxy7xogbu72bor4uve.us-east-1.es.amazonaws.com"

rm -f ${SHARED_DIR}/index.json
./run.sh

folder_name=$(ls -t -d /tmp/*/ | head -1)
jq ".iterations = $PODS_PER_NODE" $folder_name/index_data.json >> ${SHARED_DIR}/index_data.json
