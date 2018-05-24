def call(String authority, String srcDir, String destDir, boolean mayThrow = true) {
    script {
        if (fileExists(srcDir)) {
            def remoteDir = authority + ":" + destDir
            shellCommand "ssh", [authority, "mkdir", "-p", destDir]
            shellCommand "rsync", ["-r", srcDir + "/", remoteDir]
        } else {
            // TODO: is this branch dead code?
            def message = "publishToLogServer: Directory '${srcDir}' does not exist."
            if (mayThrow) {
                error message
            } else {
                echo message
            }
        }
    }
}
