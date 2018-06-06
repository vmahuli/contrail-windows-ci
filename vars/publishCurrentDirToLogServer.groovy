def call(String authority, String destDir) {
    def remoteDir = authority + ":" + destDir
    def srcDir = "."
    shellCommand "ssh", [authority, "mkdir", "-p", destDir]
    shellCommand "rsync", ["-r", srcDir + "/", remoteDir]
}
