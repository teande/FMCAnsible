pipeline {
  agent any

  options {
    timestamps()
    ansiColor('xterm')
    buildDiscarder(logRotator(numToKeepStr: '30'))
  }

  parameters {
    booleanParam(name: 'USE_DOCKER', defaultValue: true, description: 'Run ansible-test sanity/units with --docker')
    string(name: 'PYTHON_BIN', defaultValue: 'python3', description: 'Python interpreter used for dependency matrix virtualenvs')
    string(name: 'ANSIBLE_CORE_MATRIX', defaultValue: '2.17.14 2.18.18 2.19.11 2.20.7 2.21.2', description: 'Space-separated ansible-core versions for dependency matrix')
  }

  environment {
    ANSIBLE_LOCAL_TEMP = '/tmp/ansible-local'
    ANSIBLE_REMOTE_TEMP = '/tmp/ansible-remote'
  }

  stages {
    stage('Toolchain') {
      steps {
        sh '''
          set -eux
          python3 --version
          ansible --version || true
          ansible-test --version || true
          docker version || true
        '''
      }
    }

    stage('Sanity') {
      steps {
        sh '''
          set -eux
          test_flag=""
          if [ "${USE_DOCKER}" = "true" ]; then test_flag="--docker"; fi
          scripts/ansible-test-local.sh sanity ${test_flag} --color -v
        '''
      }
    }

    stage('Units') {
      steps {
        sh '''
          set -eux
          test_flag=""
          if [ "${USE_DOCKER}" = "true" ]; then test_flag="--docker"; fi
          scripts/ansible-test-local.sh units ${test_flag} --requirements --color -v
        '''
      }
    }

    stage('Build') {
      steps {
        sh '''
          set -eux
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
          PYTHON_BIN="${PYTHON_BIN}" ANSIBLE_CORE_MATRIX="${ANSIBLE_CORE_MATRIX}" scripts/dependency-matrix.sh
        '''
      }
    }
  }
}
