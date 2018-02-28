def prepareShellArgument(String arg) {
    return "'" + arg.replace(/'/, /'"'"'/) + "'"
}

def call(String command, ArrayList<String> args, Boolean returnStdout = false) {
    def words = [command] + args
    sh script: words.collect{ prepareShellArgument(it) }.join(' '),
       returnStdout: returnStdout
}
