module tinyview;

import std.regex;
import std.string;
import std.path;
import std.file;
import std.conv;

// Matches {% include "filename" %} and {{ variable_name }}
// m[1] is {% include "filename" %}
// m[2] is filename
// m[3] is {{ variable_name }}
// m[4] is variable_name
const PATTERN = ctRegex!(`(\{%\sinclude\s"([^"]+)"\s%\})|(\{\{\s([^\}]+)\s\}\})`);

enum MissingKey
{
    empty,
    passThrough,
    error
}

struct TinyviewConfig
{
    string viewsDirectory = "./views";
    MissingKey onMissingKey = MissingKey.empty;
    int maxDepth = 3;
}

class RenderException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

struct Tinyview
{
    string content;
    TinyviewConfig config;
    string tmpl;

    string renderFile(string[string] data, string[string] partials = (string[string]).init)
    {
        tmpl = readText(buildPath(config.viewsDirectory, content));
        return render(data, partials);
    }

    string renderFile()
    {
        string[string] data;
        string[string] partials;
        return renderFile(data, partials);
    }

    string render()
    {
        string[string] data;
        string[string] partials;
        return render(data, partials);
    }

    string render(string[string] data, string[string] partials = (string[string]).init)
    {
        if (tmpl == "")
            tmpl = content;

        return render(tmpl, data, partials);
    }

    string render(string input, string[string] data, string[string] partials = (string[string]).init, int depth = 0)
    {
        // After three depth stop looking for includes
        if (depth > config.maxDepth)
            return input;

        string replacer(Captures!(string) m)
        {
            if (m[3].empty)
            {
                string replaceText;
                string includeFile = buildPath(config.viewsDirectory, m[2]);
                auto p = m[2] in partials;
                if (p !is null)
                    return render(*p, data, partials, depth+1);
                else if(includeFile.exists)
                    return render(readText(includeFile), data, partials, depth+1);

                if (config.onMissingKey == MissingKey.passThrough)
                    return m.hit;

                if (config.onMissingKey == MissingKey.error)
                    throw new RenderException(m[2] ~ " not found in partials");

                return replaceText;
            }

            auto v = m[4] in data;
            string replaceVar;
            if (v !is null)
                return *v;

            if (config.onMissingKey == MissingKey.passThrough)
                return m.hit;

            if (config.onMissingKey == MissingKey.error)
                throw new RenderException(m[4] ~ " not found in data");

            return replaceVar;
        }

        return replaceAll!(replacer)(input, PATTERN);
    }
}

unittest
{
    auto view = Tinyview("Hello {{ name }}!");
    assert (view.render(["name": "World"]) == "Hello World!");
}
