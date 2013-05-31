
library helpers;

import 'package:analyzer_experimental/src/generated/element.dart';

// TODO:

class LibraryHelper {
  LibraryElement library;
  
  List<FunctionElement> _functions;
  List<ClassElement> _types;
  
  LibraryHelper(this.library);
  
  List<FunctionElement> get functions {
    if (_functions == null) {
      _functions = [];
      
      _functions.addAll(library.definingCompilationUnit.functions);
      
      for (CompilationUnitElement cu in library.parts) {
        _functions.addAll(cu.functions);
      }
    }
    
    return _functions;
  }

  List<ClassElement> get types {
    if (_types == null) {
      _types = [];
      
      _types.addAll(library.definingCompilationUnit.types);
      
      for (CompilationUnitElement cu in library.parts) {
        _types.addAll(cu.types);
      }
    }
    
    return _types;
  }
  
}
