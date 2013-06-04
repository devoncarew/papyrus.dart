
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
import 'html_gen.dart';
import 'utils.dart';

part 'helpers.dart';

// TODO: --package-root?

// TODO: class getters/setters

// TODO: generics

// TODO: const values

// TODO: overridden methods

// TODO: icons?

Path get sdkBinPath => new Path(new Options().executable).directoryPath;
Path get sdkPath => sdkBinPath.join(new Path('..')).canonicalize();

/**
 * A Dart documentation generator.
 */
class Papyrus {
  HtmlGenerator html;
  final CSS css = new CSS();
  
  Directory out;
  List<String> excludeLibraries = [];
  List<String> libraryFiles;
  
  List<LibraryElement> libraries;
  
  Papyrus();
  
  /**
   * Parse the given list of command-line arguments and set up the state of this
   * object.
   */
  bool parseArgs(List<String> args) {
    ArgParser parser = _createArgsParser();
    ArgResults results = parser.parse(new Options().arguments);

    if (results['help']) {
      _printUsage(parser);
      return false;
    }
    
    if (results.rest.isEmpty) {
      _printUsage(parser);
      return false;
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
      return false;
    }
    
    out = new Directory(results['out']);
    excludeLibraries = results['excludes'] == null ?
        [] : results['excludes'].split(',');
    libraryFiles = results.rest;
    
    return true;
  }
  
  // args handling
  
  ArgParser _createArgsParser() {
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

  void _printUsage(ArgParser parser) {
    print('usage: dart papyrus <options> path/to/library1 path/to/library2');
    print('');
    print('where <options> is one or more of:');
    print(parser.getUsage().replaceAll('\n\n', '\n'));
  }

  void generate() {
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    
    // process the given libraries
    libraries = parseLibraries(libraryFiles);
    libraries.sort(elementCompare);
    
    // create the out directory
    if (!out.existsSync()) {
      out.createSync(recursive: true);
    }
    
    // remove excluded libraries
    libraries.removeWhere(
        (LibraryElement library) => excludeLibraries.contains(library.name));
    
    // generate the html files
    for (LibraryElement library in libraries) {
      generateLibrary(library);
    }
    
    // copy the css resource into 'out'
    File f = new File.fromPath(new Path(out.path).append(css.getCssName()));
    f.writeAsStringSync(css.getCssContent());
    
    double seconds = stopwatch.elapsedMilliseconds / 1000.0;
    
    print('');
    print("Documented ${libraries.length} "
    "librar${libraries.length == 1 ? 'y' : 'ies'} in "
    "${seconds.toStringAsFixed(1)} seconds.");
  }
  
  void generateLibrary(LibraryElement library) {
    File f = new File.fromPath(new Path(out.path).append(getFileNameFor(library)));
    
    print('generating ${f.path}');
    
    html = new HtmlGenerator();
    html.start(title: library.name, cssRef: css.getCssName());
    
    generateHeader(library);
    
    html.startTag('div', attributes: "class='container'");
    html.startTag('div', attributes: "class='row'");
    
    // left nav
    html.startTag('div', attributes: "class='span3'");
    html.startTag('ul', attributes: 'class="nav nav-tabs nav-stacked left-nav"');
    for (LibraryElement lib in libraries) {
      if (lib == library) {
        html.startTag('li', attributes: 'class="active"');
      } else {
        html.startTag('li');
      }
      html.writeln('<a href="${getFileNameFor(lib)}">'
      '<i class="icon-chevron-right"></i> ${lib.name}</a>');
      html.endTag(); // li
    }
    html.endTag(); // ul.nav
    html.endTag(); // div.span3
    
    // main content
    html.startTag('div', attributes: "class='span9'");

    html.tag('h1', contents: library.name);
    
    html.writeln('<hr>');
    
    LibraryHelper lib = new LibraryHelper(library);
    
    html.startTag('dl', attributes: 'class="dl-horizontal"');
    
    List<VariableHelper> variables = lib.getVariables();
    List<AccessorHelper> accessors = lib.getAccessors();
    List<FunctionHelper> functions = lib.getFunctions();
    List<TypedefHelper> typedefs = lib.getTypedefs();
    
    createToc(variables);
    createToc(accessors);
    createToc(functions);
    createToc(typedefs);
    createTocEntry('Classes', lib.types);
    
    html.endTag(); // dl
    
    printComments(library);
    
    generateElements(variables);
    generateElements(accessors);
    generateElements(functions);
    generateElements(typedefs);
    
    lib.types.forEach(generateClass);
    
    html.writeln('<hr>');
    
    html.endTag(); // div.span9

    html.endTag(); // div.row
    
    html.endTag(); // div.container
    
    generateFooter(library);
    
    html.end();
    
    // write the file contents
    f.writeAsStringSync(html.toString());
  }

  void generateHeader(LibraryElement library) {
    // header
    html.startTag('header');
    html.endTag();
  }
  
  void generateFooter(LibraryElement library) {
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
  }
  
  void createTocEntry(String name, List elements, [var f]) {
    if (!elements.isEmpty) {
      html.tag('dt', contents: name);
      
      html.startTag('dd');
      
      for (Element e in elements) {
        if (f != null) {
          html.writeln('${f(e)}<br>');
        } else {
          html.writeln('${createLinkedName(e)}<br>');
        }
      }
      
      html.endTag();
    }
  }

  void createToc(List<ElementHelper> elements) {
    if (!elements.isEmpty) {
      html.tag('dt', contents: elements[0].typeName);
      
      html.startTag('dd');
      
      for (ElementHelper e in elements) {
        html.writeln('${e.createLinkedSummary(this)}<br>');
      }
      
      html.endTag();
    }
  }

  void generateElements(List<ElementHelper> elements, [bool header = true]) {
    if (!elements.isEmpty) {
      html.tag('h4', contents: elements[0].typeName);
      if (header) {
        html.startTag('div', attributes: "class='indent'");
      }
      elements.forEach(generateElement);
      if (header) {
        html.endTag();
      }
    }
  }
  
  void generateElement(ElementHelper f) {
    html.startTag('strong', newLine: false);
    html.write('${createAnchor(f.element)}');
    html.write(f.createLinkedDescription(this));    
    html.endTag();
    
    printComments(f.element);
  }

  void printComments(Element e, [bool indent = true]) {
    String comments = e.computeDocumentationComment();
    
    if (comments != null) {
      if (indent) {
        html.startTag('div', attributes: "class='indent'");
      }
      
      html.tag('p', contents: prettifyDocs(comments));
      
      if (indent) {
        html.endTag();
      }
    } else {
      if (indent) {
        html.tag('div', attributes: "class='indent'");
      }
    }
  }

  void generateClass(ClassElement c) {
    ClassHelper helper = new ClassHelper(c);
    
    html.writeln('<hr>');
    html.writeln(createAnchor(c));
    
    html.startTag('h4');
    //html.write('<i class="icon-leaf"></i>');
    if (c.isAbstract()) {
      html.write('abstract ');
    }
    html.write('class ${c.name}');
    
    if (c.supertype != null && c.supertype.element.supertype != null) {
      html.write(' extends ${createLinkedName(c.supertype.element)}');
    }
    
    if (!c.interfaces.isEmpty) {
      html.write(' implements');
      
      for (int i = 0; i < c.interfaces.length; i++) {
        if (i == 0) {
          html.write(' ');
        } else {
          html.write(', ');
        }
        
        html.write(createLinkedName(c.interfaces[i].element));
      }
    }
    
    // TODO: mixins
    
    html.endTag();
    
    html.startTag('dl', attributes: 'class="dl-horizontal"');
    createToc(helper.getStaticFields());
    createToc(helper.getInstanceFields());
    createToc(helper.getCtors());
    createToc(helper.getMethods());
    html.endTag();
    
    printComments(c);
    
    generateElements(helper.getStaticFields(), false);
    generateElements(helper.getInstanceFields(), false);
    generateElements(helper.getCtors(), false);
    generateElements(helper.getMethods(), false);
  }

  void generateField(FieldElement f) {
    html.startTag('dt');
    html.writeln('${createAnchor(f)}Field ${f.name}');
    html.endTag();
    
    html.startTag('dd');
    html.startTag('p');
    if (f.isStatic()) {
      html.write('static ');
    }
    if (f.isFinal()) {
      html.write('final ');
    }
    if (f.isConst()) {
      html.write('const ');
    }
    html.write(createLinkedName(f.type.element));
    html.writeln(' ${f.name}');
    html.endTag();
    
    printComments(f);
    
    html.endTag();
  }

  void generateConstructor(ConstructorElement ctor) {
    html.startTag('dt');
    html.writeln('${createAnchor(ctor)}Constructor ${ctor.name}()');
    html.endTag();
    
    html.startTag('dd');
    html.startTag('p');
    if (ctor.isStatic()) {
      html.write('static ');
    }
    html.write(createLinkedName(ctor.type.element));
    html.writeln(' ${ctor.name}(${printParams(ctor.parameters)})');
    html.endTag();
    
    printComments(ctor);
    
    html.endTag();  
  }

  void generateMethod(MethodElement m) {
    html.startTag('strong', newLine: false);
    html.write('${createAnchor(m)}');
    
    if (m.isStatic()) {
      html.write('static ');
    }
    if (m.isAbstract()) {
      html.write('abstract ');
    }
    html.write(createLinkedReturnTypeName(m.type));
    html.write(' ${m.name}(${printParams(m.parameters)})');
    html.endTag();
    
    printComments(m);    
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
      return '${c.name}.${e.name}';
    }
    
    if (c != null) {
      if (e is ConstructorElement) {
        String name;
        if (e.name.isEmpty) {
          name = c.name;
        } else {
          name = '${c.name}.${e.name}';
        }
        return "<a href='${getFileNameFor(e.library)}#${c.name}.${e.name}'>${name}</a>";
      } else {
        return "<a href='${getFileNameFor(e.library)}#${c.name}.${e.name}'>${e.name}</a>";
      }
    } else {
      return "<a href='${getFileNameFor(e.library)}#${e.name}'>${e.name}</a>";
    }
  }
  
  String createLinkedReturnTypeName(FunctionType type) {
    if (type.returnType.element == null) {
      if (type.returnType.name != null) {
        return type.returnType.name;
      } else {
        return '';
      }
    } else {
      return createLinkedName(type.returnType.element);
    }
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
    libraries.addAll(library.exportedLibraries);
  }
  
  return libraries.toList();
}

String createAnchor(Element e) {
  ClassElement c = getEnclosingElement(e);
  
  if (c != null) {
    return '<a id="${c.name}.${e.name}"></a>';
  } else {
    return '<a id="${e.name}"></a>';
  }
}

ClassElement getEnclosingElement(Element e) {
  if (e is MethodElement) {
    return (e as MethodElement).enclosingElement;
  } else if (e is FieldElement) {
    return (e as FieldElement).enclosingElement;
  } else if (e is ConstructorElement) {
    return (e as ConstructorElement).enclosingElement;
  } else {
    return null;
  }
}
