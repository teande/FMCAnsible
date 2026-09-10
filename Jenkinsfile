pipeline {
  agent { label 'fmcansible-cicd' }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '30'))
    disableConcurrentBuilds()
  }

  parameters {
    booleanParam(name: 'USE_DOCKER', defaultValue: true, description: 'Run ansible-test sanity/units with --docker')
    booleanParam(name: 'RUN_CDFMC_LIVE', defaultValue: false, description: 'Run the serialized cdFMC live integration jobs after quality checks')
    booleanParam(name: 'RUN_ONPREM_LIVE', defaultValue: false, description: 'Run the serialized on-prem FMC live integration jobs after quality checks')
    booleanParam(name: 'RUN_LONG_AUTH_TEST', defaultValue: false, description: 'Include the long on-prem token-refresh test')
    string(name: 'PYTHON_BIN', defaultValue: 'python3', description: 'Python interpreter used for dependency matrix virtualenvs')
    string(name: 'ANSIBLE_TEST_CORE_VERSION', defaultValue: '2.21.3', description: 'ansible-core version used to run sanity, units, and collection build')
    string(name: 'ANSIBLE_CORE_MATRIX', defaultValue: '2.17.14 2.18.18 2.19.11 2.20.7 2.21.2', description: 'Space-separated ansible-core versions for dependency matrix')
  }

  environment {
    ANSIBLE_LOCAL_TEMP = '/tmp/ansible-local'
    ANSIBLE_REMOTE_TEMP = '/tmp/ansible-remote'
    CI_VENV = "${WORKSPACE}@tmp/fmcansible-ci-venv"
  }

  stages {
    stage('Toolchain') {
      steps {
        sh '''
          set -eux
          python3 -m venv "${CI_VENV}"
          . "${CI_VENV}/bin/activate"
          python -m pip install --disable-pip-version-check --upgrade pip
          python -m pip install --disable-pip-version-check "ansible-core==${ANSIBLE_TEST_CORE_VERSION:-2.21.3}"
          python --version
          ansible --version
          ansible-test --version
          if [ "${USE_DOCKER:-true}" = "true" ]; then
            docker version
          fi
        '''
      }
    }

    stage('Sanity') {
      steps {
        sh '''
          set -eux
          . "${CI_VENV}/bin/activate"
          test_flag=""
          if [ "${USE_DOCKER:-true}" = "true" ]; then test_flag="--docker"; fi
          scripts/ansible-test-local.sh sanity ${test_flag} --color -v
        '''
      }
    }

    stage('Units') {
      steps {
        sh '''
          set -eux
          . "${CI_VENV}/bin/activate"
          test_flag=""
          if [ "${USE_DOCKER:-true}" = "true" ]; then test_flag="--docker"; fi
          scripts/ansible-test-local.sh units ${test_flag} --requirements --color -v
        '''
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -eux
          . "${CI_VENV}/bin/activate"
          rm -rf dist
          mkdir -p dist
          ANSIBLE_LOCAL_TEMP="${ANSIBLE_LOCAL_TEMP}" ANSIBLE_REMOTE_TEMP="${ANSIBLE_REMOTE_TEMP}" \
            ansible-galaxy collection build --output-path dist
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'dist/*.tar.gz', allowEmptyArchive: true
        }
      }
    }

    stage('Dependency Matrix') {
      steps {
        sh '''
          set -eux
          . "${CI_VENV}/bin/activate"
          USE_DOCKER="${USE_DOCKER:-true}" \
            PYTHON_BIN="${PYTHON_BIN:-python3}" \
            ANSIBLE_CORE_MATRIX="${ANSIBLE_CORE_MATRIX:-2.17.14 2.18.18 2.19.11 2.20.7 2.21.2}" \
            scripts/dependency-matrix.sh
        '''
      }
    }

    stage('Stage Live Test Inputs') {
      when {
        expression { params.RUN_CDFMC_LIVE || params.RUN_ONPREM_LIVE }
      }
      steps {
        stash name: 'fmcansible-live-inputs', includes: 'dist/*.tar.gz,tests/live/**'
        script {
          node('built-in') {
            deleteDir()
            unstash 'fmcansible-live-inputs'
            lock(resource: 'fmcansible-live-lab') {
              sh '''
                set -eux
                artifact=$(find dist -maxdepth 1 -name 'cisco-fmcansible-*.tar.gz' -print -quit)
                test -n "$artifact"
                test -x /var/lib/jenkins/fmcansible-ci/venv/bin/ansible-galaxy
                rm -rf /var/lib/jenkins/fmcansible-ci/collections/ansible_collections/cisco/fmcansible
                /var/lib/jenkins/fmcansible-ci/venv/bin/ansible-galaxy collection install \
                  "$artifact" --force -p /var/lib/jenkins/fmcansible-ci/collections
                rsync -a --delete tests/live/ /var/lib/jenkins/fmcansible-ci/live/
                printf '%s\n' "$GIT_COMMIT" \
                  > /var/lib/jenkins/fmcansible-ci/collections/.fmcansible-source-revision
              '''
            }
          }
        }
      }
    }

    stage('Live Integration') {
      when {
        expression { params.RUN_CDFMC_LIVE || params.RUN_ONPREM_LIVE }
      }
      parallel {
        stage('cdFMC Live') {
          when {
            expression { params.RUN_CDFMC_LIVE }
          }
          steps {
            script {
              def failures = []
              [
                '/FMCAnsible/Live/cdFMC/Core/fmcansible-cdfmc-core-live',
                '/FMCAnsible/Live/cdFMC/fmcansible-cdfmc-dynamic-object-api-check',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-lab-setup',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-static-live',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-ecmp-pbr',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-bgp-live',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-ospfv2-live',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-ospfv3-live',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-eigrp-live',
                '/FMCAnsible/Live/cdFMC/Routing/fmcansible-cdfmc-routing-dynamic-discovery',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-policy-live',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-policy-hub-live',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-policy-full-mesh-live',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-route-live',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-dvti-live',
                '/FMCAnsible/Live/cdFMC/Site-to-Site VPN/fmcansible-cdfmc-s2s-sdwan-live'
              ].each { jobName ->
                def run = build job: jobName, wait: true, propagate: false
                if (run.result != 'SUCCESS') {
                  failures.add("${jobName}: ${run.result}")
                }
              }
              if (failures) {
                error("cdFMC live failures:\n${failures.join('\n')}")
              }
            }
          }
        }

        stage('On-Prem Live') {
          when {
            expression { params.RUN_ONPREM_LIVE }
          }
          steps {
            script {
              def failures = []
              [
                '/FMCAnsible/Live/On-Prem/Setup/fmcansible-onprem-baseline-sync',
                '/FMCAnsible/Live/On-Prem/Core/fmcansible-onprem-core-live',
                '/FMCAnsible/Live/On-Prem/RAVPN/fmcansible-onprem-ravpn-live',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-lab-setup',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-static-live',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-ecmp-pbr',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-bgp-live',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-ospfv2-live',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-ospfv3-live',
                '/FMCAnsible/Live/On-Prem/Routing/fmcansible-onprem-routing-eigrp-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-policy-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-policy-hub-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-policy-full-mesh-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-route-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-dvti-live',
                '/FMCAnsible/Live/On-Prem/Site-to-Site VPN/fmcansible-onprem-s2s-sdwan-live',
                '/FMCAnsible/Live/On-Prem/RAVPN/fmcansible-onprem-ravpn-live'
              ].each { jobName ->
                def run = build job: jobName, wait: true, propagate: false
                if (run.result != 'SUCCESS') {
                  failures.add("${jobName}: ${run.result}")
                }
              }
              if (params.RUN_LONG_AUTH_TEST) {
                def run = build job: '/FMCAnsible/Live/On-Prem/Authentication/fmcansible-onprem-token-refresh-longrun', wait: true, propagate: false
                if (run.result != 'SUCCESS') {
                  failures.add("on-prem token refresh: ${run.result}")
                }
              }
              if (failures) {
                error("On-prem live failures:\n${failures.join('\n')}")
              }
            }
          }
        }
      }
    }
  }

  post {
    always {
      sh 'rm -rf "${CI_VENV}"'
    }
  }
}
