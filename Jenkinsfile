#!/usr/bin/env groovy

gems = [
  'analytics',
  'banner_grade_export_plugin',
  'canvas_geoip',
  'canvas_salesforce_plugin',
  'canvas_webhooks',
  'canvas_zendesk_plugin',
  'canvasnet_registration',
  'catalog_provisioner',
  'custom_reports',
  'demo_site',
  'ims_es_importer_plugin',
  'instructure_misc_plugin',
  'migration_tool',
  'multiple_root_accounts',
  'phone_home_plugin',
  'respondus_lockdown_browser',
  'uuid_provisioner'
]

def withGerritCredentials = { Closure command ->
  withCredentials([
    sshUserPrivateKey(credentialsId: '44aa91d6-ab24-498a-b2b4-911bcb17cc35', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USERNAME')
  ]) { command() }
}

def fetchFromGerrit = { String repo, String path, String customRepoDestination = null, String sourcePath = null ->
  withGerritCredentials({ ->
    sh """
      mkdir -p ${path}/${customRepoDestination ?: repo}
      GIT_SSH_COMMAND='ssh -i \"$SSH_KEY_PATH\" -l \"$SSH_USERNAME\"' \
        git archive --remote=ssh://$GERRIT_URL/${repo} master ${sourcePath == null ? '' : sourcePath} | tar -x -C ${path}/${customRepoDestination ?: repo}
    """
  })
}

def getImageTag() {
  // if (env.GERRIT_EVENT_TYPE == 'patchset-created') {
  //   GERRIT__REFSPEC will be in the form 'refs/changes/63/181863/8'
  //   we want a name in the form '63.181863.8'
  NAME = "${env.GERRIT_REFSPEC}".minus('refs/changes/').replaceAll('/','.')
  return "$DOCKER_REGISTRY_FQDN/jenkins/canvas-lms:$NAME"
  // } else {
  //   return "$DOCKER_REGISTRY_FQDN/jenkins/canvas-lms:$GERRIT_BRANCH"
  // }
}

pipeline {
  agent { label 'docker' }

  options {
    ansiColor('xterm')
    parallelsAlwaysFailFast()
  }

  environment {
    GERRIT_PORT = '29418'
    GERRIT_URL = "$GERRIT_HOST:$GERRIT_PORT"
    IMAGE_TAG = getImageTag()
  }

  stages {
    stage('Debug') {
      steps {
        timeout(time: 20, unit: 'SECONDS') {
          sh 'printenv | sort'
        }
      }
    }

    stage('Plugins and Config Files') {
      steps {
        timeout(time: 3) {
          script {
            withGerritCredentials({ ->
              sh '''
                gerrit_message="Gerrit Builder Started $JOB_BASE_NAME\nTag: $IMAGE_TAG\nBuild: $BUILD_URL"
                ssh -i "$SSH_KEY_PATH" -l "$SSH_USERNAME" -p $GERRIT_PORT \
                  hudson@$GERRIT_HOST gerrit review -m "'$gerrit_message'" $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER
              '''
            })
            gems.each { gem -> fetchFromGerrit(gem, 'gems/plugins') }
            fetchFromGerrit('qti_migration_tool', 'vendor', 'QTIMigrationTool')
            fetchFromGerrit('gerrit_builder', 'config', '', 'canvas-lms/config')
          }
        }
      }
    }

    stage('Rebase') {
      when { expression { env.GERRIT_EVENT_TYPE == 'patchset-created' } }
      steps {
        sh '''
          git config user.name $GERRIT_EVENT_ACCOUNT_NAME
          git config user.email $GERRIT_EVENT_ACCOUNT_EMAIL
          git rebase --preserve-merges origin/$GERRIT_BRANCH
        '''
      }
    }

    stage('Build Image') {
      steps {
        timeout(time: 20) {
          sh 'docker build -t $IMAGE_TAG .'
        }
      }
    }

    stage('Publish Image') {
      steps {
        timeout(time: 5) {
          sh 'docker push $IMAGE_TAG'
        }
      }
    }
  }

  post {
    success {
      script {
        withGerritCredentials({ ->
          sh '''
            gerrit_message="Gerrit Builder $JOB_BASE_NAME Successful.\nTag: $IMAGE_TAG\nBuild: $BUILD_URL"
            ssh -i "$SSH_KEY_PATH" -l "$SSH_USERNAME" -p $GERRIT_PORT \
              hudson@$GERRIT_HOST gerrit review -m "'$gerrit_message'" $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER
          '''
        })
      }
    }

    unsuccessful {
      script {
        withGerritCredentials({ ->
          sh '''
            gerrit_message="Gerrit Builder $JOB_BASE_NAME Failed.\nTag: $IMAGE_TAG\nBuild: $BUILD_URL"
            ssh -i "$SSH_KEY_PATH" -l "$SSH_USERNAME" -p $GERRIT_PORT \
              hudson@$GERRIT_HOST gerrit review -m "'$gerrit_message'" $GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER
          '''
        })
      }
    }
  }
}
