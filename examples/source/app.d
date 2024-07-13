import std.stdio;

import tinyview;

void main()
{
    TinyviewConfig config;
    config.viewsDirectory = "./views";
    config.onMissingKey = MissingKey.empty;

    auto txt = `Hello World!{% include "head.html" %} Welcome {{ name }} {% include "footer.html" %}`;
    // auto matches = matchAll(txt, PATTERN);
    // writeln(matches);
    // foreach(m;matches)
    // 	writeln(m.hit, " ", m[1], " ", m[2]);
    
    // auto txt1 = replaceAll!(replacer)(txt, PATTERN);
    // writeln(txt1);
    string[string] files = [
                  "head.html": "<head></head>",
                  "footer.html": "<footer></footer>"
                  ];

    string[string] vars = [
                 "name": "AAA",
                 "value": "100"
                 ];

    auto res = Tinyview(txt, config).render(vars, files);
    writeln(res);

    auto filename = "index.html";
    auto res1 = Tinyview(filename, config).renderFile(vars, files);
    writeln(res1);
}
