pipeline {
    agent {
        label "мастер"
    }
    stages {
        stage("Get Deps..") {
            echo "\n\n\n ===== Getting dependense === \n\n\n"
            sh "mix deps.get"
        }
        stage("Running tests..") {
            echo "\n\n\n ===== Running tests === \n\n\n"
            sh "mix test"
        }
        stage("Building..") {
            echo "\n\n\n ===== Building elixir app === \n\n\n"
            sh "MIX_ENV=prod mix release"
        }
    }
}