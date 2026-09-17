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

struct Tinyview
{
    TinyviewSettings settings;
    string tmpl_;

    Tinyview fromString(string txt)
    {
        return templateFromString(
            txt,
            onMissingKey: this.settings.onMissingKey,
            viewsDirectory: this.settings.viewsDirectory,
            includes: this.settings.includes,
            maxDepth: this.settings.maxDepth
        );
    }

    Tinyview fromFile(string path)
    {
        return templateFromFile(
            path,
            onMissingKey: this.settings.onMissingKey,
            viewsDirectory: this.settings.viewsDirectory,
            includes: this.settings.includes,
            maxDepth: this.settings.maxDepth
        );
    }
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

/*
  Returns ready to render template instance.

  ---
  auto name = "TINYVIEW";
  auto tmpl = templateFromString("Hello {{ name }}!");
  tmpl.render!(name);
  tmpl.render(["name": name]);
  ---
 */
Tinyview templateFromString(
    string txt,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3)
{
    Tinyview view;
    view.settings.onMissingKey = onMissingKey;
    view.settings.viewsDirectory = viewsDirectory;
    view.settings.includes = includes;
    view.settings.maxDepth = maxDepth;
    view.tmpl_ = txt;

    return view;
}

/*
  Returns ready to render template instance.

  ---
  auto name = "TINYVIEW";
  auto tmpl = templateFromFile("index.html");
  tmpl.render!(name);
  tmpl.render(["name": name]);
  ---
 */
Tinyview templateFromFile(
    string path,
    string[string] data = string[string].init,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3)
{
    string fullPath = buildPath(viewsDirectory, path);
    string content = (path in includes) ? includes[path] : readText(fullPath);

    Tinyview view;
    view.settings.onMissingKey = onMissingKey;
    view.settings.viewsDirectory = viewsDirectory;
    view.settings.includes = includes;
    view.settings.maxDepth = maxDepth;
    view.tmpl_ = content;

    return view;
}

/*
  Render Tinyview template from String

  ---
  auto name = "TINYVIEW";
  renderString!(name)("Hello {{ name }}!");
  renderString("Hello {{ name }}!", ["name": name]); // Same as above
  ---
 */
string renderString(Args...)(
    string txt,
    string[string] data = string[string].init,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3,
    int depth = 1)
{
    static if (Args.length > 0)
        data = tinyviewDataFromArgs!(Args).data;

    return renderText(txt, data, onMissingKey, viewsDirectory, includes, maxDepth, depth);
}

/*
  Render Tinyview template from a File

  ---
  auto name = "TINYVIEW";
  renderFile!(name)("index.html");
  renderFile("index.html", ["name": name]); // Same as above
  ---
 */
string renderFile(Args...)(
    string path,
    string[string] data = string[string].init,
    MissingKey onMissingKey = MissingKey.init,
    string viewsDirectory = "./views",
    string[string] includes = string[string].init,
    int maxDepth = 3,
    int depth = 0)
{
    static if (Args.length > 0)
        data = tinyviewDataFromArgs!(Args).data;

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

/*
  ---
  Tinyview view;
  auto name = "TINYVIEW";
  view.renderFile!(name)("index.html");
  view.renderFile("index.html", ["name": name]); // same as above
  ---
 */
string renderFile(Args...)(ref Tinyview view, string fileName, string[string] data = string[string].init)
{
    static if (Args.length > 0)
        data = tinyviewDataFromArgs!(Args).data;

    return renderFile(
            fileName,
            data: data,
            onMissingKey: view.settings.onMissingKey,
            viewsDirectory: view.settings.viewsDirectory,
            includes: view.settings.includes,
            maxDepth: view.settings.maxDepth
        );
}

/*
  ---
  auto tmpl = templateFromString("Hello {{ name }}!");
  auto name = "TINYVIEW";
  tmpl.render!(name);
  tmpl.render!(["name": name]); // same as above
  ---

  ---
  auto tmpl = templateFromFile("index.html");
  auto name = "TINYVIEW";
  tmpl.render!(name);
  tmpl.render!(["name": name]); // same as above
  ---
 */
string render(Args...)(ref Tinyview view, string tmpl = "", string[string] data = string[string].init)
{
    static if (Args.length > 0)
        data = tinyviewDataFromArgs!(Args).data;

    if (tmpl == "")
        tmpl = view.tmpl_;

    return renderString(
        tmpl,
        data: data,
        onMissingKey: view.settings.onMissingKey,
        viewsDirectory: view.settings.viewsDirectory,
        includes: view.settings.includes,
        maxDepth: view.settings.maxDepth
    );
}

/*
  ---
  Tinyview view;
  auto name = "TINYVIEW";
  view.renderString!(name)("Hello {{ name }}!");
  view.renderString("Hello {{ name }}!", ["name": name]); // Same as above
  ---
 */
string renderString(Args...)(ref Tinyview view, string tmpl, string[string] data = string[string].init)
{
    return render!(Args)(view, tmpl, data);
}

unittest
{
    string viewsDirectory = "./tests/views";
    string tmpl = "Hello {{ name }}!";
    string name = "World";
    auto data = tinyviewDataFromArgs!(name);

    assert (renderString(tmpl, ["name": "World"]) == "Hello World!");
    assert (renderString!(name)(tmpl) == "Hello World!");
    assert (renderString(tmpl, data.data) == "Hello World!");
    assert (renderString("Hello") == "Hello");
    assert (renderFile("hello.txt", ["name": "World"], viewsDirectory: viewsDirectory) == "Hello World!\n");
    assert (renderFile("hello.txt", data.data, viewsDirectory: viewsDirectory) == "Hello World!\n");
    assert (renderFile!(name)("hello.txt", viewsDirectory: viewsDirectory) == "Hello World!\n");

    assert(
        renderFile(
            "include_tests.txt",
            ["to": "User A", "from": "Company A", "product": "Product A"],
            viewsDirectory: viewsDirectory
            ),
        readText(viewsDirectory ~ "/output1.txt")
    );

    assert(
        renderString(
            readText(viewsDirectory ~ "/include_tests.txt"),
            ["to": "User A", "from": "Company A", "product": "Product A"],
            viewsDirectory: viewsDirectory
            ),
        readText(viewsDirectory ~ "/output1.txt")
    );

    Tinyview view;
    view.settings.viewsDirectory = viewsDirectory;

    assert(view.render(tmpl, ["name": "World"]) == "Hello World!");
    assert(view.render!(name)(tmpl) == "Hello World!");

    auto t1 = templateFromString(tmpl);
    assert(t1.render!(name) == "Hello World!");
}
