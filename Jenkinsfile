stage('Preparation') {
    node('builder') {
        deleteDir()

        // Use the same repo and branch as was used to checkout Jenkinsfile:
        checkout scm

        // If not using `Pipeline script from SCM`, specify the branch manually:
        // git branch: 'master', url: 'https://github.com/codilime/contrail-windows-tools/'

        stash name: "CIScripts", includes: "CIScripts/**"
    }
}

stage('Build') {
    node('builder') {
        env.THIRD_PARTY_CACHE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/"
        env.DRIVER_SRC_PATH = "github.com/codilime/contrail-windows-docker"
        env.BUILD_ONLY = "1"
        env.BUILD_IN_RELEASE_MODE = "false"
        env.SIGNTOOL_PATH = "C:/Program Files (x86)/Windows Kits/10/bin/x64/signtool.exe"
        env.CERT_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/codilime.com-selfsigned-cert.pfx"
        env.CERT_PASSWORD_FILE_PATH = "C:/BUILD_DEPENDENCIES/third_party_cache/common/certs/certp.txt"

        env.MSBUILD = "C:/Program Files (x86)/MSBuild/14.0/Bin/MSBuild.exe"
        env.GOPATH = pwd()

        unstash "CIScripts"

        powershell script: './CIScripts/Build.ps1'
        //stash name: "WinArt", includes: "output/**/*"
        //stash name: "buildLogs", includes: "logs/**"
    }
}

def SpawnedTestbedVMNames = ''

stage('Provision') {
    node('ansible') {
        sh 'echo "TODO use ansible for provisioning"'
        // set $SpawnedTestbedVMNames here
    }
}

stage('Deploy') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"
        // unstash "WinArt"

        env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        env.ARTIFACTS_DIR = "output"

        // powershell script: './CIScripts//Deploy.ps1'
    }
}

stage('Test') {
    node('tester') {
        deleteDir()
        unstash "CIScripts"

        // env.TESTBED_HOSTNAMES = SpawnedTestbedVMNames
        // env.ARTIFACTS_DIR = "output"

        // powershell script: './CIScripts/Test.ps1'
    }
}

stage('Post-build') {
    node('master') {
        // cleanWs()
        sh 'echo "TODO environment cleanup"'
        // unstash "buildLogs"
        // TODO correct flags for rsync
        sh "echo rsync logs/ logs.opencontrail.org:${JOB_NAME}/${BUILD_ID}"
        // cleanWS{}
    }
}
