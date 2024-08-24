# Tinyview

A small library to support string substitutions and partial includes.

Many use cases doesn't need any complex logic in the templates. Tinyview specially designed for those use cases. For example, to generate static HTML pages or to generate email templates etc.

## Syntax
Syntax is very easy to remember. Inspired by Liquid and Jinja2, but only variable substitution and partial includes supported.

### Variable substitution

```
{{ variable_name }}
```

Example,

```
Dear {{ first_name }},

Thank you for the feedback!

Regards
Tinyview
```

### Include other files

```
{% include "filename" %}
```

Example,

```
{% include "top.html" %}
<h1>{{ title }}</h1>
<div class="content">
{{ content }}
</div>
{% include "footer.html" %}
```

## Install

Add `tinyview` to your project by running the following command.

```
dub add tinyview
```

## Hello World!

```d
import std.stdio;

import tinyview;

Tinyview view;

void main()
{
    view = new Tinyview;
    auto tmpl = "Hello {{ name }}!";
    writeln(view.render(tmpl, ["name": "World"]));
    // OR with args
    auto name = "World";
    auto data = tinyviewDataFromArgs!(name);
    writeln(view.render(tmpl, data));
}
```

```console
$ dub run
Hello World!
```

## Usage

### String templates

```d
auto data = [
    "name": "Admin",
    "status": "Running"
];

auto tmpl = q"[Dear {{ name }},

Application status is {{ status }}.

]";
auto view = new Tinyview;
writeln(view.render(tmpl, data));
```

### String templates with string partials

```d
TinyviewSettings settings;
settings.includes = [
    "top.html": "<!DOCTYPE html><html><head><title>{{ title }}</title></head><body>",
    "footer.html": "</body></html>"
];

auto data = [
    "title": "Hello World!",
    "content": "Content text"
];

auto tmpl = `{% include "top.html" %}{{ content }}{% include "footer.html" %}`;
auto view = new Tinyview(settings);
writeln(view.render(tmpl, data));
```

### Render templates from the filesystem

Tinyview will look for templates in `settings.viewsDirectory` (Default is `"./views"`).

```console
$ ls views
index.html
top.html
seo.html
footer.html
```

```d
auto data = [
    "title": "Hello World!",
    "content": "Content text"
];

auto filename = "index.html";
auto view = new Tinyview;
writeln(view.renderFile(filename, data));
```

### Settings

**viewsDirectory** (Default: `"./views"`) - When file name is provided, it will be looked up in this directory.

```d
settings.viewsDirectory = "./";
```

**onMissingKey** (Default: `MissingKey.empty`) - By default, render function adds empty string if the variable or include file is not available. Other available options are: 
- `MissingKey.error` to raise error when variable or include file not found. 
- `MissingKey.passThrough` to retain the variable and include syntax as is when not found. Useful for multistage processing.

```d
settings.onMissingKey = MissingKey.error;
```

**maxDepth** (Default: `3`) - If a partial file includes other files and variables, max depth to parse the included template and replace.

```d
settings.maxDepth = 2;
```

**includes** - Partial data to load when called from `{% include "filename" %}`

```d
settings.includes = [
    "top.html": "<!DOCTYPE html><html><head><title>{{ title }}</title></head><body>",
    "footer.html": "</body></html>"
];
```

```d
TinyviewConfig config;
settings.viewsDirectory = "./";
settings.onMissingKey = MissingKey.error;
settings.maxDepth = 2;
settings.includes = [
    "top.html": "<!DOCTYPE html><html><head><title>{{ title }}</title></head><body>",
    "footer.html": "</body></html>"
];

auto view = new Tinyview(settings);
auto tmpl = "Hello {{ name }}!";
writeln(view.render(tmpl, ["name": "World"]));
```

## Using with the Web frameworks

### With Serverino

```d
import serverino;
import tinyview;

mixin ServerinoMain;

Tinyview view;

static this()
{
    view = new Tinyview;
}

@endpoint @route!"/"
void homePageHandler(Request request, Output output)
{
    auto data = [
        "title": "Hello World!"
    ];
    output ~= view.renderFile("index.html", data);
}
```

### With Vibe.d

```d
import vibe.http.server;
import vibe.http.router;
import vibe.core.core : runApplication;
import tinyview;

Tinyview view;

static this()
{
    view = new Tinyview;
}

void homePageHandler(HTTPServerRequest req, HTTPServerResponse res)
{
    auto data = [
        "title": "Hello World!"
    ];

    res.writeBody(view.renderFile("index.html", data));
}

void main()
{
    auto router = new URLRouter;
    router.get("/", &homePageHandler);

    auto settings = new HTTPServerSettings;
	settings.port = 8080;
	listenHTTP(settings, router);
    runApplication;
}
```

### With Handy-Httpd

```d
import handy_httpd;
import handy_httpd.handlers;
import tinyview;

Tinyview view;

static this()
{
    view = new Tinyview;
}

void homePageHandler(ref HttpRequestContext ctx)
{
    auto data = [
        "title": "Hello World!"
    ];

    ctx.response.writeBodyString(view.renderFile("index.html", data));
}

void main()
{
    auto pathHandler = new PathHandler()
        .addMapping(Method.GET, "/", &homePageHandler);
    new HttpServer(pathHandler).start();
}
```

## Contributing

- Fork it (https://github.com/aravindavk/tinyview/fork)
- Create your feature branch (git checkout -b my-new-feature)
- Commit your changes (git commit -asm 'Add some feature')
- Push to the branch (git push origin my-new-feature)
- Create a new Pull Request

## Contributors

- Aravinda VK - Creator and Maintainer
