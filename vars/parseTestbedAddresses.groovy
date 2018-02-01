def call(String filePath) {
    def contents = readFile(filePath)

    def testbeds = contents.split('\n').findAll { line ->
        line.matches('^.*-wintb[0-9]{2};.*$')
    }

    def addresses = testbeds.collect { line ->
        line.split(';')[1]
    }

    return addresses
}
