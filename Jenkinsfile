pipeline {
  agent { label 'fmcansible-cicd' }

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  parameters {
    booleanParam(name: 'USE_DOCKER', defaultValue: true, description: 'Run ansible-test sanity/units with --docker')
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
  }

  post {
    always {
      sh 'rm -rf "${CI_VENV}"'
    }
  }
}
