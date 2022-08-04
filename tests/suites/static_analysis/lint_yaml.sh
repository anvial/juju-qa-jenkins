yaml_check() {
  FILE="${1}"

  py=$(cat <<EOF
import yaml, sys

def path(loader, tag_suffix, node):
  tags = [u'!include-raw:', u'!include:', u'!include-raw-escape:']
  if tag_suffix not in tags:
    raise Exception('unknown tag: {}, expected: {}'.format(tag_suffix, tags))
  return 'input-raw'

yaml.add_multi_constructor('', path)
yaml.load(sys.stdin, Loader=yaml.Loader)
EOF
)

  OUT=$(python3 -c "${py}" 2>&1 < "${FILE}" || true)
  if [ -n "${OUT}" ]; then
    echo ""
    echo "$(red 'Found some issues:')"
    echo "${OUT}"
    exit 1
  fi
}

run_yaml_check() {
  FILES="${2}"

  echo "$FILES" | while IFS= read -r line; do yaml_check "${line}"; done
}

run_yaml_deadcode() {
  OUT=$(go run tests/suites/static_analysis/deadcode/main.go "$(pwd)" <<EOF 2>&1 || true
files:
  skip:
    - .github/workflows/static-analysis.yml
    - .github/workflows/local-deployment.yml
jobs:
  ignore:
    - ci-build-juju
    - ci-gating-tests
    - ci-proving-ground-tests
    - clean-lxd-environments
    - clean-maas-environments
    - clean-workspaces
    - run-build-check-lxd
    - github-juju-check-jobs
    - github-juju-merge-jobs
    - github-juju-pylibjuju-jobs
    - github-integration-tests-pylibjuju
    - github-mgo-check-jobs
    - github-mgo-merge-jobs
    - github-prs
    - sync-ntp
    - z-clean-resources-azure
    - z-clean-resources-aws
    - z-clean-resources-gce
    - z-clean-resources-gke
    - z-clean-resources-aks
    - z-clean-resources-equinix
    - z-clean-resources-rackspace
    - z-clean-resources-vsphere
    - z-clean-resources-windows
    - z-clean-resources-eks
    - z-clean-resources-ecr
    - run-unit-tests-lxd
    - upload-s3-agent-binaries
    - unit-tests-s390x-bionic
    - unit-tests-race-arm64
    - unit-tests-ppc64el-bionic
    - unit-tests-centos9
    - unit-tests-arm64-bionic
    - unit-tests-arm64
    - run-unit-tests-lxd-bionic
    - nw-deploy-xenial-s390x-lxd
    - nw-deploy-xenial-ppc64el-lxd
    - make-windows-installer
    - gating-functional-tests-s390x
    - gating-functional-tests-ppc64el

    # TODO (stickupkid): The followng jobs seem to be orphan jobs with in the
    # jenkins suite. We should clean them up to ensure that they do run, or
    # are removed.
    - nw-caas-deploy-charms-kubernetes-core-iaas-controller
    - nw-caas-deploy-charms-microk8s-iaas-controller
    - nw-upgrade-lxd-profile-lxd
    - integration-tests
    - public-clouds
    - lxd-src-command-focal-base
    - nw-deploy-focal-amd64-lxd
EOF
)
  if [ -n "${OUT}" ]; then
    echo ""
    echo "$(red 'Found some issues:')"
    echo "${OUT}"
    exit 1
  fi
}

run_yaml_simplify() {
  OUT=$(go run tests/suites/static_analysis/simplify/main.go "$(pwd)" <<EOF 2>&1 || true
files:
  skip:
    - .github/workflows/static-analysis.yml
    - .github/workflows/local-deployment.yml
jobs:
  ignore:
    # TODO (stickupkid): Clean these commands up and simplify the following jobs
    # so that they don't require a multi-job for no reason.
    - ci-build-juju:Packaging
    - github-mgo-check-jobs:github-mgo-check-jobs
    - github-mgo-merge-jobs:github-mgo-merge-jobs
    - github-juju-merge-jobs:github-juju-merge-jobs
    - github-juju-pylibjuju-jobs:github-juju-pylibjuju-jobs
    - github-juju-check-jobs:github-juju-check-jobs
    - test-bootstrap-multijob:IntegrationTests-bootstrap
    - test-upgrade-multijob:IntegrationTests-upgrade
    - test-upgrade_series-multijob:IntegrationTests-upgrade_series
    - test-deploy-arm64:IntegrationTests-deploy-arm64
    - gating-integration-tests-arm64:gating-integration-tests-arm64
EOF
)
  if [ -n "${OUT}" ]; then
    echo ""
    echo "$(red 'Found some issues:')"
    echo "${OUT}"
    exit 1
  fi
}

test_static_analysis_yaml() {
  if [ "$(skip 'test_static_analysis_yaml')" ]; then
      echo "==> TEST SKIPPED: static yaml analysis"
      return
  fi

  (
    set_verbosity

    cd .. || exit

    FILES=$(find ./* -name '*.yml')

    go mod download

    # YAML static analysis
    if which python >/dev/null 2>&1; then
      run "run_yaml_check" "${FILES}"
    else
      echo "python not found, yaml static analysis disabled"
    fi

    # YAML deadcode elimiation
    if which go >/dev/null 2>&1; then
      run "run_yaml_deadcode"
    else
      echo "go not found, yaml deadcode disabled"
    fi

    # YAML simplify
    if which go >/dev/null 2>&1; then
      run "run_yaml_simplify"
    else
      echo "go not found, yaml simplify disabled"
    fi
  )
}
