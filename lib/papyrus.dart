
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
import 'model_utils.dart';
import 'utils.dart';

part 'helpers.dart';

// TODO: clean up generics support

// TODO: --title paramater

// TODO: --footer parameter

// TODO: generate a type hierarchy

// TODO: generate an element index

void main() {
  Papyrus generator = new Papyrus();

  if (generator.parseArgs(new Options().arguments)) {
    generator.generate();
  }
}

/**
 * A Dart documentation generator.
 */
class Papyrus implements Generator {
  HtmlGenerator html;
  final CSS css = new CSS();

  Directory out;
  List<String> excludeLibraries = [];
  List<String> includedLibraries = [];
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
    excludeLibraries = results['exclude'] == null ?
        [] : results['exclude'].split(',');
    includedLibraries = results['include'] == null ?
        [] : results['include'].split(',');
    libraryFiles = results.rest;

    return true;
  }

  // args handling

  ArgParser _createArgsParser() {
    ArgParser parser = new ArgParser();
    parser.addOption(
        'exclude',
        help: 'a comma-separated list of library names to ignore');
    parser.addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'show command help');
    parser.addOption(
        'include',
        help: 'a comma-separated list of library names to include');
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

    // create the out directory
    if (!out.existsSync()) {
      out.createSync(recursive: true);
    }

    addIncluded(libraries, includedLibraries);

    // remove excluded libraries
    for (String pattern in excludeLibraries) {
      libraries.removeWhere((l) => l.name.startsWith(pattern));
    }

    libraries.removeWhere(
        (LibraryElement library) => excludeLibraries.contains(library.name));

    libraries.sort(elementCompare);

    // generate the html files
    for (LibraryElement library in libraries) {
      generateLibrary(library);
    }

    // copy the css resource into 'out'
    File f = joinFile(new Directory(out.path), [css.getCssName()]);
    f.writeAsStringSync(css.getCssContent());

    double seconds = stopwatch.elapsedMilliseconds / 1000.0;

    print('');
    print("Documented ${libraries.length} "
    "librar${libraries.length == 1 ? 'y' : 'ies'} in "
    "${seconds.toStringAsFixed(1)} seconds.");
  }

  void addIncluded(List<LibraryElement> libraries, List<String> includedLibraries) {
    AnalysisContext context = libraries[0].context;

    for (Source libSource in context.librarySources) {
      LibraryElement element = context.getLibraryElement(libSource);

      for (String pattern in includedLibraries) {
        if (element.name.startsWith(pattern)) {
          if (!libraries.contains(element)) {
            libraries.add(element);
          }
        }
      }
    }
  }

  void generateLibrary(LibraryElement library) {
    File f = joinFile(new Directory(out.path), [getFileNameFor(library)]);

    print('generating ${f.path}');

    html = new HtmlGenerator();
    html.start(title: 'Library ${library.name}', cssRef: css.getCssName());

    generateHeader(library);

    html.startTag('div', attributes: "class='container'", newLine: false);
    html.writeln();
    html.startTag('div', attributes: "class='row'", newLine: false);
    html.writeln();

    // left nav
    html.startTag('div', attributes: "class='span3'");
    html.startTag('ul', attributes: 'class="nav nav-tabs nav-stacked left-nav"');
    for (LibraryElement lib in libraries) {
      if (lib == library) {
        html.startTag('li', attributes: 'class="active"', newLine: false);
        html.write('<a href="${getFileNameFor(lib)}">'
        '<i class="chevron-nav icon-white icon-chevron-right"></i> '
        '${lib.name}</a>');
      } else {
        html.startTag('li', newLine: false);
        html.write('<a href="${getFileNameFor(lib)}">'
        '<i class="chevron-nav icon-chevron-right"></i> '
        '${lib.name}</a>');
      }
      html.endTag(); // li
    }
    html.endTag(); // ul.nav
    html.endTag(); // div.span3

    // main content
    html.startTag('div', attributes: "class='span9'");

    html.tag('h1', contents: library.name);

    if (!library.exportedLibraries.isEmpty) {
      html.startTag('p');
      html.write('exports ');
      for (int i = 0; i < library.exportedLibraries.length; i++) {
        if (i > 0) {
          html.write(', ');
        }

        LibraryElement lib = library.exportedLibraries[i];
        if (libraries.contains(lib)) {
          html.write('<a href="${getFileNameFor(lib)}">${lib.name}</a>');
        } else {
          html.write(lib.name);
        }
      }
      html.endTag();
    }

    html.writeln('<hr>');

    LibraryHelper lib = new LibraryHelper(library);

    html.startTag('dl', attributes: "class=dl-horizontal");

    List<VariableHelper> variables = lib.getVariables();
    List<AccessorHelper> accessors = lib.getAccessors();
    List<FunctionHelper> functions = lib.getFunctions();
    List<TypedefHelper> typedefs = lib.getTypedefs();
    List<ClassHelper> types = lib.getTypes();

    createToc(variables);
    createToc(accessors);
    createToc(functions);
    createToc(typedefs);
    createToc(types);

    html.endTag(); // dl

    printComments(library);

    generateElements(variables);
    generateElements(accessors);
    generateElements(functions);
    generateElements(typedefs);

    types.forEach(generateClass);

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

  void createToc(List<ElementHelper> elements) {
    if (!elements.isEmpty) {
      html.tag('dt', contents: elements[0].typeName);

      html.startTag('dd');

      for (ElementHelper e in elements) {
        html.writeln('${createIconFor(e.element)}${e.createLinkedSummary(this)}<br>');
      }

      html.endTag();
    }
  }

  void generateElements(List<ElementHelper> elements, [bool header = true]) {
    if (!elements.isEmpty) {
      html.tag('h4', contents: elements[0].typeName);
      if (header) {
        html.startTag('div', attributes: "class=indent");
      }
      elements.forEach(generateElement);
      if (header) {
        html.endTag();
      }
    }
  }

  void generateAnnotations(List<ElementAnnotation> annotations) {
    if (!annotations.isEmpty) {
      html.write('<i class="icon-info-sign icon-hidden"></i> ');
      for (ElementAnnotation a in annotations) {
        Element e = a.element;
        // TODO: I don't believe we get back the right elements for const
        // ctor annotations
        html.writeln('@${e.name} ');
      }
      html.writeln('<br>');
    }
  }

  void generateElement(ElementHelper f) {
    html.startTag('b', newLine: false);
    html.write('${createAnchor(f.element)}');

    generateAnnotations(f.element.metadata);

    html.write(createIconFor(f.element));
    if (f.element is MethodElement) {
      html.write(generateOverrideIcon(f.element as MethodElement));
    }
    html.write(f.createLinkedDescription(this));
    html.endTag();

    printComments(f.element);
  }

  String createIconFor(Element e) {
    if (e is PropertyAccessorElement) {
      PropertyAccessorElement a = (e as PropertyAccessorElement);

      if (a.isGetter) {
        return '<i class=icon-circle-arrow-right></i> ';
      } else {
        return '<i class=icon-circle-arrow-left></i> ';
      }
    } else if (e is ClassElement) {
      return '<i class=icon-leaf></i> ';
    } else if (e is FunctionTypeAliasElement) {
      return '<i class=icon-cog></i> ';
    } else if (e is PropertyInducingElement) {
      return '<i class=icon-minus-sign></i> ';
    } else if (e is ConstructorElement) {
      return '<i class=icon-plus-sign></i> ';
    } else if (e is ExecutableElement) {
      return '<i class=icon-ok-sign></i> ';
    } else {
      return '';
    }
  }

  String generateOverrideIcon(MethodElement element) {
    Element o = getOverriddenElement(element);

    if (o == null) {
      return '';
    } else if (!isDocumented(o)) {
      return "<i title='Overrides ${getNameFor(o)}' "
          "class='icon-circle-arrow-up icon-disabled'></i> ";
    } else {
      return "<a href='${createHrefFor(o)}'>"
          "<i title='Overrides ${getNameFor(o)}' "
          "class='icon-circle-arrow-up'></i></a> ";
    }
  }

  void generateClass(ClassHelper helper) {
    ClassElement c = helper.element;

    html.write(createAnchor(c));
    html.writeln('<hr>');
    html.startTag('h4');

    generateAnnotations(c.metadata);

    html.write(createIconFor(c));
    if (c.isAbstract) {
      html.write('Abstract class ${c.name}');
    } else {
      html.write('Class ${c.name}');
    }

    if (c.supertype != null && c.supertype.element.supertype != null) {
      html.write(' extends ${createLinkedTypeName(c.supertype)}');
    }

    if (!c.mixins.isEmpty) {
      html.write(' with');

      for (int i = 0; i < c.mixins.length; i++) {
        if (i == 0) {
          html.write(' ');
        } else {
          html.write(', ');
        }

        html.write(createLinkedTypeName(c.mixins[i]));
      }
    }

    if (!c.interfaces.isEmpty) {
      html.write(' implements');

      for (int i = 0; i < c.interfaces.length; i++) {
        if (i == 0) {
          html.write(' ');
        } else {
          html.write(', ');
        }

        html.write(createLinkedTypeName(c.interfaces[i]));
      }
    }

    html.endTag();

    html.startTag('dl', attributes: 'class=dl-horizontal');
    createToc(helper.getStaticFields());
    createToc(helper.getInstanceFields());
    createToc(helper.getAccessors());
    createToc(helper.getCtors());
    createToc(helper.getMethods());
    html.endTag();

    printComments(c);

    generateElements(helper.getStaticFields(), false);
    generateElements(helper.getInstanceFields(), false);
    generateElements(helper.getAccessors(), false);
    generateElements(helper.getCtors(), false);
    generateElements(helper.getMethods(), false);
  }

  void printComments(Element e, [bool indent = true]) {
    String comments = getDocumentationFor(e);

    if (comments != null) {
      if (indent) {
        html.startTag('div', attributes: "class=indent");
      }

      html.tag('p', contents: prettifyDocs(
          new PapyrusResolver(this, e), comments));

      if (indent) {
        html.endTag();
      }
    } else {
      if (indent) {
        html.tag('div', attributes: "class=indent");
      }
    }
  }

  String getDocumentationFor(Element e) {
    if (e == null) {
      return null;
    }

    String comments = e.computeDocumentationComment();

    if (comments != null) {
      return comments;
    }

    if (canOverride(e)) {
      return getDocumentationFor(getOverriddenElement(e));
    } else {
      return null;
    }
  }

  bool isDocumented(Element e) {
    return libraries.contains(e.library);
  }

  String createHrefFor(Element e) {
    if (!isDocumented(e)) {
      return '';
    }

    ClassElement c = getEnclosingElement(e);

    if (c != null) {
      return '${getFileNameFor(e.library)}#${c.name}.${escapeBrackets(e.name)}';
    } else {
      return '${getFileNameFor(e.library)}#${e.name}';
    }
  }

//  String createLinkedName(Element e) {
//    if (e is ClassElement) {
//      ClassElement c = e as ClassElement;
//
//      if (c.type.typeArguments.isEmpty) {
//        return _createLinkedName(e);
//      } else {
//        return '${_createLinkedName(e)}${printLinkedTypeArgs(c.type.typeArguments)}';
//      }
//    } else {
//      return _createLinkedName(e);
//    }
//  }
//
//  String printLinkedTypeArgs(List<Type2> typeArguments) {
//    StringBuffer buf = new StringBuffer();
//    buf.write('&lt;');
//    for (int i = 0; i < typeArguments.length; i++) {
//      if (i > 0) {
//        buf.write(', ');
//      }
//      Type2 t = typeArguments[i];
//
//      //if (t.bound != null) {
//        buf.write(createLinkedName(t.element));
//      //} else {
//      //  buf.write(t.name);
//      //}
//    }
//    buf.write('&gt;');
//    return buf.toString();
//  }

  String createLinkedName(Element e, [bool appendParens = false]) {
    if (e == null) {
      return '';
    }

    if (!isDocumented(e)) {
      return htmlEscape(e.name);
    }

    if (e.name.startsWith('_')) {
      return htmlEscape(e.name);
    }

    ClassElement c = getEnclosingElement(e);

    if (c != null && c.name.startsWith('_')) {
      return '${c.name}.${htmlEscape(e.name)}';
    }

    if (c != null && e is ConstructorElement) {
      String name;
      if (e.name.isEmpty) {
        name = c.name;
      } else {
        name = '${c.name}.${htmlEscape(e.name)}';
      }
      if (appendParens) {
        return "<a href=${createHrefFor(e)}>${name}()</a>";
      } else {
        return "<a href=${createHrefFor(e)}>${name}</a>";
      }
    } else {
      String append = '';

      if (appendParens && (e is MethodElement || e is FunctionElement)) {
        append = '()';
      }

      return "<a href=${createHrefFor(e)}>${htmlEscape(e.name)}$append</a>";
    }
  }

  String createLinkedTypeName(Type2 type) {
    StringBuffer buf = new StringBuffer();

    if (type is TypeVariableType) {
      buf.write(type.element.name);
    } else {
      buf.write(createLinkedName(type.element));
    }

    if (type is ParameterizedType) {
      ParameterizedType pType = type as ParameterizedType;

      if (!pType.typeArguments.isEmpty) {
        buf.write('&lt;');
        for (int i = 0; i < pType.typeArguments.length; i++) {
          if (i > 0) {
            buf.write(', ');
          }
          Type2 t = pType.typeArguments[i];
          buf.write(createLinkedTypeName(t));
        }
        buf.write('&gt;');
      }
    }

    return buf.toString();
  }

  String getNameFor(Element e) {
    ClassElement c = getEnclosingElement(e);

    // TODO: upscale this! handle ctors
    String ext = (e is ExecutableElement) ? '()' : '';

    return '${c.name}.${htmlEscape(e.name)}${ext}';
  }

  String createLinkedReturnTypeName(FunctionType type) {
    if (type.returnType.element == null) {
      if (type.returnType.name != null) {
        return type.returnType.name;
      } else {
        return '';
      }
    } else {
      return createLinkedTypeName(type.returnType);
    }
  }

  String printParams(List<ParameterElement> params) {
    StringBuffer buf = new StringBuffer();

    for (ParameterElement p in params) {
      if (buf.length > 0) {
        buf.write(', ');
      }

      if (p.type != null && p.type.name != null) {
        buf.write(createLinkedTypeName(p.type));
        buf.write(' ');
      }

      buf.write(p.name);
    }

    return buf.toString();
  }
}

abstract class Generator {
  String createLinkedName(Element e, [bool appendParens = false]);
  String createLinkedReturnTypeName(FunctionType type);
  String printParams(List<ParameterElement> params);
}

class PapyrusResolver extends CodeResolver {
  Generator generator;
  Element element;

  PapyrusResolver(this.generator, this.element);

  String resolveCodeReference(String reference) {
    Element e = (element as ElementImpl).getChild(reference);

    if (e is LocalElement || e is TypeVariableElement) {
      e = null;
    }

    if (e != null) {
      return generator.createLinkedName(e, true);
    } else {
      //return "<a>$reference</a>";
      return "$reference";
    }
  }
}

Directory getSdkDir() {
  // look for --dart-sdk on the command line
  List<String> args = new Options().arguments;
  if (args.contains('--dart-sdk')) {
    return new Directory(args[args.indexOf('dart-sdk') + 1]);
  }

  // look in env['DART_SDK']
  if (Platform.environment['DART_SDK'] != null) {
    return new Directory(Platform.environment['DART_SDK']);
  }

  // look relative to the dart executable
  // TODO: file a bug re: the path to the executable and the cwd
  return getParent(new File(Platform.executable).directory);
}

String getFileNameFor(LibraryElement library) {
  return '${library.name}.html';
}

// TODO: --package-root

List<LibraryElement> parseLibraries(List<String> files) {
  DartSdk sdk = new DirectoryBasedDartSdk(new JavaFile(getSdkDir().path));

  ContentCache contentCache = new ContentCache();

  List<UriResolver> resolvers = [new DartUriResolver(sdk), new FileUriResolver()];

  JavaFile packagesDir = new JavaFile('packages');

  if (packagesDir.exists()) {
    resolvers.add(new PackageUriResolver([packagesDir]));
  }

  SourceFactory sourceFactory = new SourceFactory.con1(contentCache, resolvers);

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
    libraries.addAll(library.exportedLibraries);
  }

  return libraries.toList();
}

String createAnchor(Element e) {
  ClassElement c = getEnclosingElement(e);

  if (c != null) {
    return '<a id=${c.name}.${escapeBrackets(e.name)}></a>';
  } else {
    return '<a id=${e.name}></a>';
  }
}
