
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
  List<LibraryElement> libraries = parseLibraries(files);
  
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

void generateLibraryDocs(LibraryElement library, Directory out) {
  File f = new File.fromPath(new Path(out.path).append(getFileNameFor(library)));
  
  print('generating ${f.path}');
  
  HtmlGenerator html = new HtmlGenerator();
  
  html.start(library.name);
  
  // header
  html.startTag('header');
  html.endTag();
  
  html.startTag('div', "class='container'");
  
  // TODO: generate
  html.tag('h1', '${library.name} library');
  
  LibraryHelper lib = new LibraryHelper(library);
  
  // Functions
  html.tag('h3', 'Functions');
  html.startTag('ul');
  
  for (FunctionElement f in lib.functions) {
    html.tag('li', '${f.name}()');
  }
  
  html.endTag();
  
  // Classes
  html.tag('h3', 'Classes');
  html.startTag('ul');
  
  for (ClassElement t in lib.types) {
    html.tag('li', '${t.name}');
  }
  
  html.endTag();
  
  // div.contents
  html.endTag();
  
  // footer
  html.startTag('footer');
  html.endTag();
  
  html.end();
  
  // write the file contents
  f.writeAsStringSync(html.toString());
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
  
  List<LibraryElement> libraries = [];
  
  for (String filePath in files) {
    print('parsing ${filePath}...');
    
    Source librarySource = new FileBasedSource.con1(
        contentCache, new JavaFile(filePath));
    LibraryElement library = context.computeLibraryElement(librarySource);
    CompilationUnit unit = context.resolveCompilationUnit(librarySource, library);
    
    libraries.add(library);
  }
  
  return libraries;
}


