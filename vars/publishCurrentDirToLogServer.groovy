def call(String authority, String destDir, boolean mayThrow = true) {
    script {
        def remoteDir = authority + ":" + destDir
        shellCommand "ssh", [authority, "mkdir", "-p", destDir]
        shellCommand "rsync", ["-r", srcDir + "/", remoteDir]
    }
}
