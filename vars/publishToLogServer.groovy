def call(Map logServer, String src, String destDir, boolean mayThrow = true) {
    script {
        if (fileExists(src)) {
            sh "ssh ${logServer.user}@${logServer.addr} \"mkdir -p ${destDir}\""
            sh "rsync ${src} ${logServer.user}@${logServer.addr}:${destDir}"
        } else {
            def message = "publishToLogServer: File '${src}' does not exist."
            if (mayThrow) {
                error message
            } else {
                echo message
            }
        }
    }
}
