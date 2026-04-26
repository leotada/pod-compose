module core.util;

import std.string;
import std.algorithm : canFind;
import std.array : appender;

@safe:

/// Quote a single shell argument safely using POSIX single-quote escaping.
/// Always wraps the result in single quotes so it can be embedded in a
/// shell command string without further interpretation.
string shellQuote(string s) pure
{
    auto app = appender!string();
    app.put('\'');
    foreach (c; s)
    {
        if (c == '\'')
            app.put("'\\''");
        else
            app.put(c);
    }
    app.put('\'');
    return app.data;
}

/// Quote only if the string contains shell-significant characters.
/// Empty strings are quoted too.
string shellQuoteIfNeeded(string s) pure
{
    if (s.length == 0)
        return "''";
    foreach (c; s)
    {
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
                || (c >= '0' && c <= '9') || c == '/' || c == '_' || c == '-'
                || c == '.' || c == ':' || c == '=' || c == ',' || c == '@'
                || c == '+'))
        {
            return shellQuote(s);
        }
    }
    return s;
}

/// Build a JSON-style array literal usable as `--entrypoint '["a","b"]'`.
string jsonStringArray(string[] items) pure
{
    auto app = appender!string();
    app.put('[');
    foreach (i, it; items)
    {
        if (i > 0)
            app.put(',');
        app.put('"');
        foreach (c; it)
        {
            if (c == '\\' || c == '"')
            {
                app.put('\\');
                app.put(c);
            }
            else if (c == '\n')
                app.put("\\n");
            else if (c == '\t')
                app.put("\\t");
            else if (c == '\r')
                app.put("\\r");
            else
                app.put(c);
        }
        app.put('"');
    }
    app.put(']');
    return app.data;
}

unittest
{
    assert(shellQuote("hello") == "'hello'");
    assert(shellQuote("a b") == "'a b'");
    assert(shellQuote("it's") == "'it'\\''s'");
    assert(shellQuoteIfNeeded("hello") == "hello");
    assert(shellQuoteIfNeeded("a b") == "'a b'");
    assert(shellQuoteIfNeeded("") == "''");
    assert(jsonStringArray(["a", "b"]) == `["a","b"]`);
    assert(jsonStringArray([`a"b`]) == `["a\"b"]`);
}
