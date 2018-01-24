def call(String filePath) {
    def contents = readFile(filePath)

    def inventory = contents.split('\n').collect { line ->
        def fields = line.split(';')
        fields[0]
    }

    return inventory
}
