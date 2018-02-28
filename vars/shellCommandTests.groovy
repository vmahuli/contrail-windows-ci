def call() {
    echo "Running shellCommandTests"

    def result = shellCommand('echo', ['foo', 'bar  baz', "q'uux"], true);
    assert result.trim() == /foo bar  baz q'uux/

    echo "OK"
}
