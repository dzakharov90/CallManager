pipeline {
    agent {
        label ("${env.AGENT_NAME}")
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '100')) 
        disableConcurrentBuilds()
        timestamps()
    }
    node('master'){
        stages {
            stage("Get Deps..") {
                steps {
                    script{
                        echo "\n\n\n ===== Getting dependense === \n\n\n"
                        sh "mix deps.get"
                    }
                }
            }
            stage("Running tests..") {
                steps {
                    script {
                        echo "\n\n\n ===== Running tests === \n\n\n"
                        sh "mix test"
                    }
                }
            }
            stage("Building..") {
                steps {
                    script {
                        echo "\n\n\n ===== Building elixir app === \n\n\n"
                        sh "MIX_ENV=prod mix release"
                    }
                }
            }
        }
    }
}