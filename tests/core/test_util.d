module core.test_util;

import core.util;
import std.stdio;

unittest
{
    writeln("Running Util tests...");

    assert(shellQuote("hello") == "'hello'");
    assert(shellQuote("a b c") == "'a b c'");
    assert(shellQuote("it's") == "'it'\\''s'");
    assert(shellQuote("$(rm -rf /)") == "'$(rm -rf /)'");

    assert(shellQuoteIfNeeded("safe-token_1.txt") == "safe-token_1.txt");
    assert(shellQuoteIfNeeded("with space") == "'with space'");
    assert(shellQuoteIfNeeded("") == "''");

    assert(jsonStringArray(["a", "b"]) == `["a","b"]`);
    assert(jsonStringArray([`a"b`]) == `["a\"b"]`);
    assert(jsonStringArray([]) == "[]");

    writeln("  [PASS] Shell quoting and JSON arrays");
}
