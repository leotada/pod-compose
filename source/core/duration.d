module core.duration;

import std.string;
import std.conv;
import std.ascii : isDigit;

@safe:

/// Parse a compose duration string into seconds (rounded down).
/// Accepts forms like "10", "10s", "1m30s", "1h", "500ms" (truncates ms < 1s to 0).
/// Returns -1 if the input cannot be parsed.
int parseDurationSeconds(string s)
{
    long ms = parseDurationMillis(s);
    if (ms < 0)
        return -1;
    return cast(int)(ms / 1000);
}

/// Parse a compose duration string into milliseconds.
/// Accepts forms like "10", "10s", "1m30s", "1h", "500ms".
/// Returns -1 if the input cannot be parsed.
long parseDurationMillis(string s)
{
    s = s.strip;
    if (s.length == 0)
        return -1;

    // Pure integer = seconds
    bool allDigits = true;
    foreach (c; s)
    {
        if (!isDigit(c))
        {
            allDigits = false;
            break;
        }
    }
    if (allDigits)
    {
        try
            return s.to!long * 1000;
        catch (Exception)
            return -1;
    }

    long total = 0;
    size_t i = 0;
    while (i < s.length)
    {
        // Read number
        size_t start = i;
        while (i < s.length && (isDigit(s[i]) || s[i] == '.'))
            i++;
        if (start == i)
            return -1;
        string numStr = s[start .. i];
        // Read unit
        size_t uStart = i;
        while (i < s.length && !isDigit(s[i]) && s[i] != '.')
            i++;
        string unit = s[uStart .. i].strip;

        double n;
        try
            n = numStr.to!double;
        catch (Exception)
            return -1;

        long mult;
        switch (unit)
        {
        case "ms":
            mult = 1;
            break;
        case "s", "":
            mult = 1000;
            break;
        case "m":
            mult = 60_000;
            break;
        case "h":
            mult = 3_600_000;
            break;
        case "us", "µs":
            // Sub-millisecond: ignore (rounds to 0)
            mult = 0;
            break;
        case "ns":
            mult = 0;
            break;
        default:
            return -1;
        }
        total += cast(long)(n * mult);
    }
    return total;
}

unittest
{
    assert(parseDurationSeconds("10") == 10);
    assert(parseDurationSeconds("10s") == 10);
    assert(parseDurationSeconds("1m") == 60);
    assert(parseDurationSeconds("1m30s") == 90);
    assert(parseDurationSeconds("2h") == 7200);
    assert(parseDurationSeconds("500ms") == 0);
    assert(parseDurationMillis("500ms") == 500);
    assert(parseDurationMillis("1s500ms") == 1500);
    assert(parseDurationSeconds("bogus") == -1);
    assert(parseDurationSeconds("") == -1);
}
