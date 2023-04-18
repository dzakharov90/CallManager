pipeline {
    agent any
    stages {
        stage("Copying env files...") {
            steps{
                script{
                    sh "cp config/dev.exs.example config/dev.exs"
                    sh "cp config/test.exs.example config/test.exs"
                    sh "cp config/prod.exs.example config/prod.exs"
                }
            }
        }
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
                    withCredentials(credentialsId: 'postgres', usernameVariable: 'username', passwordVariable: 'password') {
                        echo "\n\n\n ===== Running tests === \n\n\n"
                        sh "mix test"
                    }
                }
            }
        }
        stage("Building..") {
            steps {
                script {
                    withCredentials(credentialsId: 'postgres', usernameVariable: 'username', passwordVariable: 'password') {
                        echo "\n\n\n ===== Building elixir app === \n\n\n"
                        sh "MIX_ENV=prod mix release"
                    }
                }
            }
        }
    }
}