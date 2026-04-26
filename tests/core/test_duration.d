module core.test_duration;

import core.duration;
import std.stdio;

unittest
{
    writeln("Running Duration tests...");

    assert(parseDurationSeconds("10") == 10);
    assert(parseDurationSeconds("10s") == 10);
    assert(parseDurationSeconds("1m") == 60);
    assert(parseDurationSeconds("1m30s") == 90);
    assert(parseDurationSeconds("2h") == 7200);
    assert(parseDurationSeconds("0") == 0);
    assert(parseDurationSeconds("500ms") == 0);
    assert(parseDurationMillis("500ms") == 500);
    assert(parseDurationMillis("1s500ms") == 1500);
    assert(parseDurationMillis("1h2m3s") == 3_723_000);

    // Invalid
    assert(parseDurationSeconds("") == -1);
    assert(parseDurationSeconds("bogus") == -1);
    assert(parseDurationSeconds("10x") == -1);

    writeln("  [PASS] Duration parsing");
}
