pipeline {
    agent {
        label any
    }
    stages {
        stage("Get Deps..") {
            steps {
                echo "\n\n\n ===== Getting dependense === \n\n\n"
                sh "mix deps.get"
            }
        }
        stage("Running tests..") {
            steps {
                echo "\n\n\n ===== Running tests === \n\n\n"
                sh "mix test"
            }
        }
        stage("Building..") {
            steps {
                echo "\n\n\n ===== Building elixir app === \n\n\n"
                sh "MIX_ENV=prod mix release"
            }
        }
    }
}