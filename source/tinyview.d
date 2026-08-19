import std.array : appender;
import std.string : indexOf, strip, replace;
import std.path : buildPath;
import std.file : readText;
import std.conv : to;

enum MissingKey
{
    empty,
    passThrough,
    error
}

enum Pattern
{
    startVariable = "{{",
    endVariable = "}}",
    startInclude = "{%",
    endInclude = "%}"
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
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}

struct TinyviewData
{
    string[string] data;

    void add(T)(string name, T value)
    {
        data[name] = value.to!string;
    }
}

TinyviewData tinyviewDataFromArgs(Args...)()
{
    TinyviewData tvData;
    static foreach(i; 0 .. Args.length)
        tvData.data[__traits(identifier, Args[i])] = Args[i].to!string;

    return tvData;
}

string renderText(
    string txt,
    string[string] data = string[string].init,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3,
    int depth = 1)
{
    auto result = appender!string();
    size_t pos = 0;
    bool noMoreVariables = false;
    bool noMoreIncludes = false;

    while (pos < txt.length)
    {
        auto openIdx1 = txt.indexOf(Pattern.startVariable, pos);
        auto openIdx2 = txt.indexOf(Pattern.startInclude, pos);
        if (openIdx1 == -1)
            noMoreVariables = true;

        if (openIdx2 == -1)
            noMoreIncludes = true;

        // No variable or Include exists
        if (noMoreVariables && noMoreIncludes)
        {
            result.put(txt[pos .. $]);
            break;
        }

        // Do not parse includes if max depth is reached
        if (depth > maxDepth)
            noMoreIncludes = true;

        // Variables exists and no includes exists OR
        // Variables exists and variable pattern index is less
        // than include pattern index
        if (!noMoreVariables && (noMoreIncludes || openIdx1 < openIdx2))
        {
            // Text before the variable
            result.put(txt[pos .. openIdx1]);

            // Parse Variable first
            auto closeIdx = txt.indexOf(Pattern.endVariable, openIdx1 + 2);
            if (closeIdx == -1)
                throw new Exception("Close pattern }} not found");

            immutable rawName = txt[openIdx1 + 2 .. closeIdx];
            immutable varName = strip(rawName);

            // Known variable, substitute its value
            if (auto val = varName in data)
                result.put(*val);
            else
            {
                // Handle Unknown variable
                switch (onMissingKey)
                {
                case MissingKey.passThrough:
                    result.put(txt[openIdx1 .. closeIdx + 2]);
                    break;
                case MissingKey.error:
                    throw new Exception("{{ " ~ varName ~ " }} not found in data");
                    break;
                default:
                    result.put("");
                    break;
                }
            }

            pos = closeIdx + 2;
        }

        // Includes exists and no variables exists OR
        // Includes exists and include pattern index is less
        // than variable pattern index
        if (!noMoreIncludes && (noMoreVariables || openIdx2 < openIdx1))
        {
            // Text before the Include
            result.put(txt[pos .. openIdx2]);

            // Parse Include first
            auto closeIdx = txt.indexOf(Pattern.endInclude, openIdx2 + 2);
            if (closeIdx == -1)
                throw new Exception("Close pattern %} not found");

            immutable rawName = txt[openIdx2 + 2 .. closeIdx];
            immutable varName = strip(rawName);
            immutable filename = varName.replace("include", "").replace("\"", "").strip;

            result.put(
                renderFile(
                    filename,
                    data: data,
                    onMissingKey: onMissingKey,
                    viewsDirectory: viewsDirectory,
                    includes: includes,
                    maxDepth: maxDepth,
                    depth: depth + 1
            ));

            pos = closeIdx + 2;
        }
    }

    return result.data;
}

string renderFile(
    string path,
    string[string] data = string[string].init,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3,
    int depth = 0)
{
    string fullPath = buildPath(viewsDirectory, path);
    string content = (path in includes) ? includes[path] : readText(fullPath);

    return renderText(
        content,
        data: data,
        onMissingKey: onMissingKey,
        viewsDirectory: viewsDirectory,
        includes: includes,
        maxDepth: maxDepth,
        depth: depth
    );
}

struct Tinyview
{
    TinyviewSettings settings;

    string renderFile(string fileName, string[string] data)
    {
        return .renderFile(
            fileName,
            data: data,
            onMissingKey: settings.onMissingKey,
            viewsDirectory: settings.viewsDirectory,
            includes: settings.includes,
            maxDepth: settings.maxDepth
        );
    }

    string renderFile(string fileName)
    {
        return .renderFile(
            fileName,
            onMissingKey: settings.onMissingKey,
            viewsDirectory: settings.viewsDirectory,
            includes: settings.includes,
            maxDepth: settings.maxDepth
        );
    }

    string renderFile(string fileName, TinyviewData data)
    {
        return this.renderFile(fileName, data.data);
    }

    string render(string tmpl)
    {
        return renderText(
            tmpl,
            onMissingKey: settings.onMissingKey,
            viewsDirectory: settings.viewsDirectory,
            includes: settings.includes,
            maxDepth: settings.maxDepth
        );
    }

    string render(string tmpl, string[string] data)
    {
        return renderText(
            tmpl,
            data: data,
            onMissingKey: settings.onMissingKey,
            viewsDirectory: settings.viewsDirectory,
            includes: settings.includes,
            maxDepth: settings.maxDepth
        );
    }

    string render(string tmpl, TinyviewData data)
    {
        return this.render(tmpl, data.data);
    }
}

unittest
{
    string viewsDirectory = "./tests/views";
    string tmpl = "Hello {{ name }}!";
    string name = "World";
    auto data = tinyviewDataFromArgs!(name);

    assert (renderText(tmpl, ["name": "World"]) == "Hello World!");
    assert (renderText(tmpl, data.data) == "Hello World!");
    assert (renderText("Hello") == "Hello");
    assert (renderFile("hello.txt", ["name": "World"], viewsDirectory: viewsDirectory) == "Hello World!\n");
    assert (renderFile("hello.txt", data.data, viewsDirectory: viewsDirectory) == "Hello World!\n");

    assert(
        renderFile(
            "include_tests.txt",
            ["to": "User A", "from": "Company A", "product": "Product A"],
            viewsDirectory: viewsDirectory
            ),
        readText(viewsDirectory ~ "/output1.txt")
    );

    assert(
        renderText(
            readText(viewsDirectory ~ "/include_tests.txt"),
            ["to": "User A", "from": "Company A", "product": "Product A"],
            viewsDirectory: viewsDirectory
            ),
        readText(viewsDirectory ~ "/output1.txt")
    );

    TinyviewSettings settings;
    settings.viewsDirectory = viewsDirectory;
    auto view = Tinyview(settings);

    assert(view.render(tmpl, ["name": "World"]) == "Hello World!");
}
