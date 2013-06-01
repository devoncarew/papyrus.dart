
library papyrus;

import 'dart:io';

import 'package:args/args.dart';

import 'package:analyzer_experimental/src/generated/ast.dart';
import 'package:analyzer_experimental/src/generated/element.dart';
import 'package:analyzer_experimental/src/generated/engine.dart';
import 'package:analyzer_experimental/src/generated/java_io.dart';
import 'package:analyzer_experimental/src/generated/sdk.dart';
import 'package:analyzer_experimental/src/generated/sdk_io.dart';
import 'package:analyzer_experimental/src/generated/source_io.dart';

import 'css.dart';
import 'helpers.dart';
import 'html_gen.dart';

// TODO: --package-root?

Path get sdkBinPath => new Path(new Options().executable).directoryPath;
Path get sdkPath => sdkBinPath.join(new Path('..')).canonicalize();

void cliMain() {
  ArgParser parser = createArgsParser();
  ArgResults results = parser.parse(new Options().arguments);

  if (results['help']) {
    printUsage(parser);
    return;
  }
  
  if (results.rest.isEmpty) {
    printUsage(parser);
    return;
  }
  
  bool allFilesExist = true;
  
  for (String str in results.rest) {
    File file = new File(str);
    
    if (!file.existsSync()) {
      allFilesExist = false;
      
      print('unable to locate ${str}');
    }
  }
  
  if (!allFilesExist) {
    exit(1);
  }
  
  String outDir = results['out'];
  List<String> excludes = results['excludes'] == null ? [] : results['excludes'].split(',');
  List<String> files = results.rest;
  
  generateDocs(files, excludes, outDir);
}

ArgParser createArgsParser() {
  ArgParser parser = new ArgParser();
  parser.addOption(
      'excludes',
      help: 'a comma-separated list of library names to ignore');
  parser.addFlag('help',
      abbr: 'h',
      negatable: false,
      help: 'show command help');
  parser.addOption(
      'out',
      defaultsTo: 'out',
      help: 'the output directory');
  return parser;  
}

void printUsage(ArgParser parser) {
  print('usage: dart papyrus <options> path/to/library1 path/to/library2');
  print('');
  print('where <options> is one or more of:');
  print(parser.getUsage().replaceAll('\n\n', '\n'));
}

void generateDocs(List<String> files, List<String> excludes, String out) {
  Stopwatch stopwatch = new Stopwatch();
  stopwatch.start();
  
  // process the given libraries
  libraries = parseLibraries(files);
  libraries.sort(elementCompare);
  
  // create the out directory
  Directory outDir = new Directory(out);
  
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  
  // remove excluded libraries
  libraries.removeWhere(
      (LibraryElement library) => excludes.contains(library.name));
  
  // generate the html files
  for (LibraryElement library in libraries) {
    generateLibraryDocs(library, outDir);
  }
  
  // copy the css resource into 'out'
  File f = new File.fromPath(new Path(outDir.path).append(css.getCssName()));
  f.writeAsStringSync(css.getCssContent());
  
  double seconds = stopwatch.elapsedMilliseconds / 1000.0;
  
  print('');
  print("Documented ${libraries.length} "
      "librar${libraries.length == 1 ? 'y' : 'ies'} in "
      "${seconds.toStringAsFixed(1)} seconds.");
}

HtmlGenerator html;
List<LibraryElement> libraries;

void generateLibraryDocs(LibraryElement library, Directory out) {
  File f = new File.fromPath(new Path(out.path).append(getFileNameFor(library)));
  
  print('generating ${f.path}');
  
  html = new HtmlGenerator();
  
  html.start(library.name);
  
  // header
  html.startTag('header');
  html.endTag();
  
  html.startTag('div', "class='container'");
  html.startTag('div', "class='row'");
  
  // left nav
  html.startTag('div', "class='span3'");
  //html.startTag('div', "class='well well-small'");
  html.startTag('ul', 'class="nav nav-tabs nav-stacked left-nav"');
  for (LibraryElement lib in libraries) {
    if (lib == library) {
      html.startTag('li', 'class="active"');
    } else {
      html.startTag('li');
    }
    html.println('<a href="${getFileNameFor(lib)}">'
        '<i class="icon-chevron-right"></i> ${lib.name}</a>');
    html.endTag(); // li
  }
  html.endTag(); // ul.nav
  //html.endTag(); // div.well
  html.endTag(); // div.span3
  
  // main content
  html.startTag('div', "class='span9'");

  html.tag('h1', library.name);
  
  html.println('<hr>');
  
  LibraryHelper lib = new LibraryHelper(library);
  
  html.startTag('dl', 'class="dl-horizontal"');
  
  // Variables
  createToc('Variables', lib.variables);
  
  // Functions
  createToc('Functions', lib.functions,
      (FunctionElement f) => '${createLinkedName(f)}(${printParams(f.parameters)})');
  
  // Typedefs
  createToc('Typedefs', lib.typeDefs);
  
  // Classes
  createToc('Classes', lib.types);
  
  // dl
  html.endTag();
  
  lib.variables.forEach(generateVariable);
    
  lib.functions.forEach(generateFunction);
  
  lib.typeDefs.forEach(generateTypedef);
  
  lib.types.forEach(generateClass);
  
  html.println('<hr>');
  
  html.endTag(); // div.span9

  html.endTag(); // div.row
  
  html.endTag(); // div.container
  
  // footer
  html.startTag('footer');
//    html.startTag('div', 'class="navbar navbar-fixed-bottom"');
//      html.startTag('div', 'class="navbar-inner"');
//        html.startTag('div', 'class="container" style="width: auto; padding: 0 20px;"');
//          html.tag('a', 'Title'); //<a class="brand" href="#">Title</a>
//          html.startTag('ul', 'class="nav"');
//            html.tag('li', 'Link');
//          html.endTag();
//        html.endTag();
//      html.endTag();
//    html.endTag();
  html.endTag();
  
  html.end();
  
  // write the file contents
  f.writeAsStringSync(html.toString());
}

void createToc(String name, List elements, [var f]) {
  if (!elements.isEmpty) {
    html.tag('dt', name);
    
    html.startTag('dd');
    
    for (Element e in elements) {
      if (f != null) {
        html.println('${f(e)}<br>');
      } else {
        html.println('${createLinkedName(e)}<br>');
      }
    }
    
    html.endTag();
  }
}

String getFileNameFor(LibraryElement library) {
  return '${library.name}.html';
}

List<LibraryElement> parseLibraries(List<String> files) {
  DartSdk sdk = new DirectoryBasedDartSdk(new JavaFile(sdkPath.toString()));
  
  ContentCache contentCache = new ContentCache();
  
  SourceFactory sourceFactory = new SourceFactory.con1(
      contentCache, [new DartUriResolver(sdk), new FileUriResolver()]);
  
  AnalysisContext context = AnalysisEngine.instance.createAnalysisContext();
  context.sourceFactory = sourceFactory;
  
  Set<LibraryElement> libraries = new Set();
  
  for (String filePath in files) {
    print('parsing ${filePath}...');
    
    Source librarySource = new FileBasedSource.con1(
        contentCache, new JavaFile(filePath));
    LibraryElement library = context.computeLibraryElement(librarySource);
    CompilationUnit unit = context.resolveCompilationUnit(librarySource, library);
    
    libraries.add(library);
    
    libraries.addAll(library.importedLibraries);
  }
  
  return libraries.toList();
}

String printParams(List<ParameterElement> params) {
  StringBuffer buf = new StringBuffer();
  
  for (ParameterElement p in params) {
    if (buf.length > 0) {
      buf.write(', ');
    }
    
    if (p.type != null && p.type.name != null) {
      buf.write(createLinkedName(p.type.element));
      buf.write(' ');
    }
    
    buf.write(p.name);
  }
  
  return buf.toString();
}

void generateVariable(VariableElement v) {
  html.startTag('p');
  html.tag('h4', '${createAnchor(v)}Variable ${v.name}');
  html.print(createLinkedName(v.type.element));
  html.println(' ${v.name}');
  html.endTag();
  
  printComments(v);
  html.println('<br>');
}

void generateFunction(FunctionElement f) {
  html.startTag('p');
  html.tag('h4', '${createAnchor(f)}Function ${f.name}()');
  if (f.isStatic()) {
    html.print('static ');
  }
  html.print(createLinkedName(f.type.element));
  html.println(' ${f.name}(${printParams(f.parameters)})');
  html.endTag();
  
  printComments(f);
  html.println('<br>');
}

void generateTypedef(FunctionTypeAliasElement t) {
  html.startTag('p');
  html.tag('h4', '${createAnchor(t)}Typedef ${t.name}');
  html.println('${t.name}');
  // TODO: finish
  
  html.endTag();
  
  printComments(t);
  html.println('<br>');
}

void printComments(Element e) {
  String comments = e.computeDocumentationComment();
  
  if (comments != null) {
    html.tag('p', prettifyDocs(comments));  
  }
}

void generateClass(ClassElement c) {
  ClassHelper helper = new ClassHelper(c);
  
  html.println('<hr>');
  
  html.startTag('p');
  html.tag('h4', '${createAnchor(c)}Class ${c.name}');
  html.print('class ${c.name}');
  
  if (c.supertype != null && c.supertype.element.supertype != null) {
    html.print(' extends ${createLinkedName(c.supertype.element)}');
  }
  
  if (!c.interfaces.isEmpty) {
    html.print(' implements');
    
    for (int i = 0; i < c.interfaces.length; i++) {
      if (i == 0) {
        html.print(' ');
      } else {
        html.print(', ');
      }
      
      html.print(createLinkedName(c.interfaces[i].element));
    }
  }
  
  // TODO: mixins
  
  html.println();
  html.endTag();
  
  html.startTag('dl', 'class="dl-horizontal"');
  createToc('Fields', helper.fields);
  createToc('Methods', helper.methods,
      (MethodElement m) => '${createLinkedName(m)}(${printParams(m.parameters)})');
  html.endTag();
  
  printComments(c);
  
  if (!helper.fields.isEmpty) {
    html.startTag('dl');
    helper.fields.forEach(generateField);
    html.endTag();
  }
  
  if (!helper.methods.isEmpty) {
    html.startTag('dl');
    helper.methods.forEach(generateMethod);
    html.endTag();
  }
}

void generateField(FieldElement f) {
  html.startTag('dt');
  html.println('${createAnchor(f)}Field ${f.name}');
  html.endTag();
  
  html.startTag('dd');
  html.startTag('p');
  html.print(createLinkedName(f.type.element));
  html.println(' ${f.name}');
  html.endTag();
  
  printComments(f);
  
  html.endTag();
}

void generateMethod(MethodElement m) {
  html.startTag('dt');
  html.println('${createAnchor(m)}Method ${m.name}()');
  html.endTag();
  
  html.startTag('dd');
  html.startTag('p');
  if (m.isStatic()) {
    html.print('static ');
  }
  if (m.isAbstract()) {
    html.print('abstract ');
  }
  html.print(createLinkedName(m.type.element));
  html.println(' ${m.name}(${printParams(m.parameters)})');
  html.endTag();
  
  printComments(m);
  
  html.endTag();
}

String createLinkedName(Element e) {
  if (!libraries.contains(e.library)) {
    return e.name;    
  }
  
  if (e.name.startsWith('_')) {
    return e.name;    
  }
  
  ClassElement c = getEnclosingElement(e);

  if (c != null && c.name.startsWith('_')) {
    return e.name;
  }
  
  if (c != null) {
    return "<a href='${getFileNameFor(e.library)}#${c.name}.${e.name}'>${e.name}</a>";
  } else {
    return "<a href='${getFileNameFor(e.library)}#${e.name}'>${e.name}</a>";
  }
}

String createAnchor(Element e) {
  if (e is FieldElement) {
    FieldElement f = e as FieldElement;
    return '<a id="${f.enclosingElement.name}.${f.name}"></a>';    
  } else if (e is MethodElement) {
    MethodElement m = e as MethodElement;
    return '<a id="${m.enclosingElement.name}.${m.name}"></a>';    
  } else {
    return '<a id="${e.name}"></a>';
  }
}

ClassElement getEnclosingElement(Element e) {
  if (e is MethodElement) {
    return (e as MethodElement).enclosingElement;
  } else if (e is FieldElement) {
    return (e as FieldElement).enclosingElement;
  } else {
    return null;
  }
}

String prettifyDocs(String docs) {
  if (docs == null) {
    return '';
  }
  
  docs = htmlEscape(docs);
  
  docs = stripComments(docs);
  
  StringBuffer buf = new StringBuffer();
  
  bool inCode = false;
  
  for (String line in docs.split('\n')) {
    // TODO: handle code sections
    
    if (inCode && !(line.startsWith('    ') || line.trim().isEmpty)) {
      inCode = false;
      buf.write('</pre>');
    } else if (line.startsWith('    ') && !inCode) {
      inCode = true;
      buf.write('<pre>');
    }
    
    if (inCode) {
      buf.write('$line\n');
    } else if (line.trim().length == 0) {
      buf.write('</p><p>');
    } else {
      buf.write('$line ');
    }
  }
  
  if (inCode) {
    buf.write('</pre>');
  }
  
  return buf.toString().trim();
}

String htmlEscape(String text) {
  return text.replaceAll('&', '&amp;').
      replaceAll('>', '&gt;').replaceAll('<', '&lt;');
}

String stripComments(String str) {
  StringBuffer buf = new StringBuffer();
  
  if (str.startsWith('///')) {
    for (String line in str.split('\n')) {
      if (line.startsWith('/// ')) {
        buf.write('${line.substring(4)}\n');
      } else if (line.startsWith('///')) {
        buf.write('${line.substring(3)}\n');
      } else {
        buf.write('${line}\n');
      }
    }
  } else {
    if (str.startsWith('/**')) {
      str = str.substring(3);
    }
    
    if (str.endsWith('*/')) {
      str = str.substring(0, str.length - 2);
    }
    
    str = str.trim();
    
    for (String line in str.split('\n')) {
      line = ltrim(line);
      
      if (line.startsWith('* ')) {
        buf.write('${line.substring(2)}\n');
      } else if (line.startsWith('*')) {
        buf.write('${line.substring(1)}\n');
      } else {
        buf.write('$line\n');
      }
    }
  }
  
  return buf.toString().trim();
}

String ltrim(String str) {
  while (str.length > 0 && (str[0] == ' ' || str[0] == '\t')) {
    str = str.substring(1);
  }
  
  return str;
}
