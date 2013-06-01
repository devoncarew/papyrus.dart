
library helpers;

import 'package:analyzer_experimental/src/generated/element.dart';

// TODO:

class LibraryHelper {
  LibraryElement library;
  
  List<TopLevelVariableElement> _variables;
  List<FunctionElement> _functions;
  List<FunctionTypeAliasElement> _typeDefs;
  List<ClassElement> _types;
  
  LibraryHelper(this.library);
  
  List<TopLevelVariableElement> get variables {
    if (_variables == null) {
      _variables = [];
      
      _variables.addAll(library.definingCompilationUnit.topLevelVariables);
      
      for (CompilationUnitElement cu in library.parts) {
        _variables.addAll(cu.topLevelVariables);
      }
      
      _variables.removeWhere((TopLevelVariableElement v) => v.name.startsWith('_'));
      _variables.sort(elementCompare);
    }
    
    return _variables;
  }
  
  List<FunctionTypeAliasElement> get typeDefs {
    if (_typeDefs == null) {
      _typeDefs = [];
      
      _typeDefs.addAll(library.definingCompilationUnit.functionTypeAliases);
      
      for (CompilationUnitElement cu in library.parts) {
        _typeDefs.addAll(cu.functionTypeAliases);
      }
      
      _typeDefs.removeWhere((FunctionTypeAliasElement f) => f.name.startsWith('_'));
      _typeDefs.sort(elementCompare);
    }
    
    return _typeDefs;
  }
  
  List<FunctionElement> get functions {
    if (_functions == null) {
      _functions = [];
      
      _functions.addAll(library.definingCompilationUnit.functions);
      
      for (CompilationUnitElement cu in library.parts) {
        _functions.addAll(cu.functions);
      }
      
      _functions.removeWhere((FunctionElement f) => f.name.startsWith('_'));
      _functions.sort(elementCompare);
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
      
      _types.removeWhere((ClassElement c) => c.name.startsWith('_'));
      _types.sort(elementCompare);
    }
    
    return _types;
  }
}

class ClassHelper {
  ClassElement cls;
  
  List<FieldElement> _fields;
  List<MethodElement> _methods;
  
  ClassHelper(this.cls);
  
  List<FieldElement>  get fields {
    if (_fields == null) {
      _fields = cls.fields.toList();      
      _fields.removeWhere((FieldElement c) => c.name.startsWith('_'));
      _fields.sort(elementCompare);
    }
    
    return _fields;    
  }
  
  List<MethodElement>  get methods {
    if (_methods == null) {
      _methods = cls.methods.toList();      
      _methods.removeWhere((MethodElement c) => c.name.startsWith('_'));
      _methods.sort(elementCompare);
    }
    
    return _methods;    
  }
}

int elementCompare(Element a, Element b) {
  return a.name.compareTo(b.name);
}
