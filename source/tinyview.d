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

struct TinyviewSettings
{
    string viewsDirectory = "./views";
    MissingKey onMissingKey = MissingKey.empty;
    int maxDepth = 3;
    string[string] includes;
}

class RenderException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

class Tinyview
{
    TinyviewSettings settings;

    this(TinyviewSettings settings = TinyviewSettings.init)
    {
        this.settings = settings;
    }

    string renderFile(string fileName, string[string] data)
    {
        auto tmpl = readText(buildPath(settings.viewsDirectory, fileName));
        return render_(tmpl, data);
    }

    string renderFile(string fileName)
    {
        string[string] data;
        return renderFile(fileName, data);
    }

    string renderFile(string fileName, TinyviewData data)
    {
        return renderFile(fileName, data.data);
    }

    string render(string tmpl)
    {
        string[string] data;
        return render_(tmpl, data);
    }

    string render(string tmpl, string[string] data)
    {
        return render_(tmpl, data);
    }

    string render(string tmpl, TinyviewData data)
    {
        return render(tmpl, data.data);
    }

    private string render_(string input, string[string] data, int depth = 0)
    {
        // After three depth stop looking for includes
        if (depth > settings.maxDepth)
            return input;

        string replacer(Captures!(string) m)
        {
            if (m[3].empty)
            {
                string replaceText;
                string includeFile = buildPath(settings.viewsDirectory, m[2]);
                auto p = m[2] in settings.includes;
                if (p !is null)
                    return render_(*p, data, depth+1);
                else if(includeFile.exists)
                    return render_(readText(includeFile), data, depth+1);

                if (settings.onMissingKey == MissingKey.passThrough)
                    return m.hit;

                if (settings.onMissingKey == MissingKey.error)
                    throw new RenderException(m[2] ~ " not found in partials");

                return replaceText;
            }

            auto v = m[4] in data;
            string replaceVar;
            if (v !is null)
                return *v;

            if (settings.onMissingKey == MissingKey.passThrough)
                return m.hit;

            if (settings.onMissingKey == MissingKey.error)
                throw new RenderException(m[4] ~ " not found in data");

            return replaceVar;
        }

        return replaceAll!(replacer)(input, PATTERN);
    }
}

struct TinyviewData
{
    string[string] data;


    void add(T)(string name, T value)
    {
        data[name] = value.to!string;
    }

    // TODO: From Struct and Class
}

TinyviewData tinyviewDataFromArgs(Args...)()
{
    TinyviewData tvData;
    static foreach(i; 0 .. Args.length)
        tvData.data[__traits(identifier, Args[i])] = Args[i].to!string;

    return tvData;
}

unittest
{
    auto view = new Tinyview;
    string tmpl = "Hello {{ name }}!";
    assert (view.render(tmpl, ["name": "World"]) == "Hello World!");

    string name = "World";
    auto data = tinyviewDataFromArgs!(name);
    assert (view.render(tmpl, data) == "Hello World!");

    assert(view.render("Hello") == "Hello");

    TinyviewSettings settings;
    settings.viewsDirectory = "./tests/views";
    view = new Tinyview(settings);
    assert(view.renderFile("hello.txt", ["name": "World"]) == "Hello World!\n");

    assert(view.renderFile("hello.txt", data) == "Hello World!\n");
}
