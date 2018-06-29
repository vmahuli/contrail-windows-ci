# Adding new flakiness patterns

1. Add an regular expression to `patterns.txt`
2. Add a test in `testcases` directory:
   The test comprises two files: 
   * `xxx.in.txt` that contains some lines that should match a pattern.
     It's recommended to use a piece from real-world logs.
     Please include at least one non-matching line.
   * `xxx.out.txt` that contains only matching lines from `xxx.in.txt`.
3. Run `./run-tests.sh` to verify correctness of a pattern.
