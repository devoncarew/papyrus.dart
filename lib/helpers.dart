
part of papyrus;

class LibraryHelper {
  LibraryElement library;
  
  List<ClassElement> _types;
  
  LibraryHelper(this.library);
  
  List<VariableHelper> getVariables() {
    List<TopLevelVariableElement> variables = [];
    
    variables.addAll(library.definingCompilationUnit.topLevelVariables);
    for (CompilationUnitElement cu in library.parts) {
      variables.addAll(cu.topLevelVariables);
    }
    
    variables..removeWhere(isPrivate)..sort(elementCompare);
    
    return variables.map((e) => new VariableHelper(e)).toList();
  }
  
  List<AccessorHelper> getAccessors() {
    List<PropertyAccessorElement> accessors = [];
    
    accessors.addAll(library.definingCompilationUnit.accessors);
    for (CompilationUnitElement cu in library.parts) {
      accessors.addAll(cu.accessors);
    }
    
    accessors..removeWhere(isPrivate)..sort(elementCompare);
    accessors.removeWhere((e) => e.isSynthetic());
    
    return accessors.map((e) => new AccessorHelper(e)).toList();
  }
  
  List<TypedefHelper> getTypedefs() {
    List<FunctionTypeAliasElement> functions = [];
    
    functions.addAll(library.definingCompilationUnit.functionTypeAliases);
    for (CompilationUnitElement cu in library.parts) {
      functions.addAll(cu.functionTypeAliases);
    }
    
    functions..removeWhere(isPrivate)..sort(elementCompare);
    
    return functions.map((e) => new TypedefHelper(e)).toList();
  }
  
  List<FunctionHelper> getFunctions() {
    List<FunctionElement> functions = [];
      
    functions.addAll(library.definingCompilationUnit.functions);
    for (CompilationUnitElement cu in library.parts) {
      functions.addAll(cu.functions);
    }
    
    functions..removeWhere(isPrivate)..sort(elementCompare);
    
    return functions.map((e) => new FunctionHelper(e)).toList();
  }

  List<ClassElement> get types {
    if (_types == null) {
      _types = [];
      
      _types.addAll(library.definingCompilationUnit.types);
      
      for (CompilationUnitElement cu in library.parts) {
        _types.addAll(cu.types);
      }
      
      _types.removeWhere(isPrivate);
      _types.sort(elementCompare);
    }
    
    return _types;
  }
}

class ClassHelper {
  ClassElement cls;
  
  ClassHelper(this.cls);
  
  List<FieldElement> _getAllfields() {
    return cls.fields.toList()..removeWhere(isPrivate)..sort(elementCompare);
  }
  
  List<FieldHelper> getStaticFields() {
    List<FieldElement> fields = _getAllfields()..removeWhere((e) => !isStatic(e));
    return fields.map((e) => new StaticFieldHelper(e)).toList();
  }
  
  List<FieldHelper> getInstanceFields() {
    List<FieldElement> fields = _getAllfields()..removeWhere(isStatic);
    return fields.map((e) => new FieldHelper(e)).toList();
  }
  
  List<AccessorHelper> getAccessors() {
    List<PropertyAccessorElement> accessors = 
        cls.accessors.toList()..removeWhere(isPrivate)..sort(elementCompare);
    accessors.removeWhere((e) => e.isSynthetic());
    return accessors.map((e) => new AccessorHelper(e)).toList();
  }
  
  List<ConstructorHelper> getCtors() {
    List<ConstructorElement> c = cls.constructors.toList()..removeWhere(isPrivate)..sort(elementCompare);
    return c.map((e) => new ConstructorHelper(e)).toList();
  }
  
  List<MethodHelper> getMethods() {
    List<MethodElement> m = cls.methods.toList()..removeWhere(isPrivate)..sort(elementCompare);
    return m.map((e) => new MethodHelper(e)).toList();
  }  
}

abstract class ElementHelper {
  Element element;
  
  ElementHelper(this.element);
  
  String get typeName;
  
  String createLinkedSummary(Papyrus papyrus) {
    return papyrus.createLinkedName(element);
  }
  
  String createLinkedDescription(Papyrus papyrus);
}

abstract class PropertyInducingHelper extends ElementHelper {
  PropertyInducingHelper(PropertyInducingElement element): super(element);
  
  PropertyInducingElement get _var => (element as PropertyInducingElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    buf.write('${papyrus.createLinkedName(element)}');
    
    String type = papyrus.createLinkedName(_var.type.element);
    
    if (!type.isEmpty) {
      buf.write(': $type');
    }
    
    return buf.toString();
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_var is PropertyInducingElement && (_var as PropertyInducingElement).isStatic()) {
      buf.write('static ');      
    }
    if (_var.isFinal()) {
      buf.write('final ');
    }
    if (_var.isConst()) {
      buf.write('const ');
    }
    
    buf.write(papyrus.createLinkedName(_var.type.element));
    buf.write(' ${element.name}');
    
    return buf.toString();
  }
}

class VariableHelper extends PropertyInducingHelper {
  VariableHelper(TopLevelVariableElement element): super(element);
  
  String get typeName => 'Top-Level Variables';
}

class FieldHelper extends PropertyInducingHelper {
  FieldHelper(FieldElement element): super(element);
  
  String get typeName => 'Fields';
}

class StaticFieldHelper extends PropertyInducingHelper {
  StaticFieldHelper(FieldElement element): super(element);
  
  String get typeName => 'Static Fields';
}

class AccessorHelper extends ElementHelper {
  AccessorHelper(PropertyAccessorElement element): super(element);
  
  String get typeName => 'Getters and Setters';
  
  PropertyAccessorElement get _acc => (element as PropertyAccessorElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_acc.isGetter()) {
      buf.write(papyrus.createLinkedName(element));
      buf.write(': ');
      buf.write(papyrus.createLinkedReturnTypeName(_acc.type));
    } else {
      buf.write('${papyrus.createLinkedName(element)}('
          '${papyrus.printParams(_acc.parameters)})');
    }
    
    return buf.toString();
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_acc.isStatic()) {
      buf.write('static ');
    }
    
    if (_acc.isGetter()) {
      buf.write('${papyrus.createLinkedReturnTypeName(_acc.type)} get ${element.name}');
    } else {
      buf.write('set ${element.name}(${papyrus.printParams(_acc.parameters)})');
    }
    
    return buf.toString();
  }
}

class FunctionHelper extends ElementHelper {
  FunctionHelper(FunctionElement element): super(element);
  
  String get typeName => 'Functions';
  
  FunctionElement get _func => (element as FunctionElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    String retType = papyrus.createLinkedReturnTypeName(_func.type);
    
    return '${papyrus.createLinkedName(element)}'
        '(${papyrus.printParams(_func.parameters)})'
        '${retType.isEmpty ? '' : ': $retType'}';
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_func.isStatic()) {
      buf.write('static ');
    }
    
    buf.write(papyrus.createLinkedReturnTypeName(_func.type));
    buf.write(' ${element.name}(${papyrus.printParams(_func.parameters)})');
    
    return buf.toString();
  }
}

class TypedefHelper extends ElementHelper {
  TypedefHelper(FunctionTypeAliasElement element): super(element);
  
  String get typeName => 'Typedefs';
  
  FunctionTypeAliasElement get _typedef => (element as FunctionTypeAliasElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    // Comparator<T>(T a, T b): int
    StringBuffer buf = new StringBuffer();
    
    buf.write(papyrus.createLinkedName(element));
    if (!_typedef.typeVariables.isEmpty) {
      buf.write('&lt;');
      for (int i = 0; i < _typedef.typeVariables.length; i++) {
        if (i > 0) {
          buf.write(', ');
        }
        buf.write(_typedef.typeVariables[i].name);
      }
      buf.write('&gt;');
    }
    buf.write('(${papyrus.printParams(_typedef.parameters)}): ');
    buf.write(papyrus.createLinkedReturnTypeName(_typedef.type));
    
    return buf.toString();
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    // typedef int Comparator<T>(T a, T b)
    
    StringBuffer buf = new StringBuffer();
    
    buf.write('typedef ${papyrus.createLinkedReturnTypeName(_typedef.type)} ${element.name}');
    if (!_typedef.typeVariables.isEmpty) {
      buf.write('&lt;');
      for (int i = 0; i < _typedef.typeVariables.length; i++) {
        if (i > 0) {
          buf.write(', ');
        }
        buf.write(_typedef.typeVariables[i].name);
      }
      buf.write('&gt;');
    }
    buf.write('(${papyrus.printParams(_typedef.parameters)}): ');
    
    return buf.toString();
  }
}

abstract class ExecutableHelper extends ElementHelper {
  ExecutableHelper(ExecutableElement element): super(element);
  
  ExecutableElement get _ex => (element as ExecutableElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    String retType = papyrus.createLinkedReturnTypeName(_ex.type);
    
    return '${papyrus.createLinkedName(element)}'
        '(${papyrus.printParams(_ex.parameters)})'
        '${retType.isEmpty ? '' : ': $retType'}';
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_ex.isStatic()) {
      buf.write('static ');
    }
    
    buf.write(papyrus.createLinkedReturnTypeName(_ex.type));
    buf.write(' ${element.name}(${papyrus.printParams(_ex.parameters)})');
    
    return buf.toString();
  }
}

class ConstructorHelper extends ExecutableHelper {
  ConstructorHelper(ConstructorElement element): super(element);
  
  String get typeName => 'Constructors';
  
  ConstructorElement get _ctor => (element as ConstructorElement);
  
  String createLinkedSummary(Papyrus papyrus) {
    return '${papyrus.createLinkedName(element)}'
        '(${papyrus.printParams(_ex.parameters)})';
  }
  
  String createLinkedDescription(Papyrus papyrus) {
    StringBuffer buf = new StringBuffer();
    
    if (_ex.isStatic()) {
      buf.write('static ');
    }
    if (_ctor.isFactory()) {
      buf.write('factory ');
    }
    
    buf.write('${_ctor.type.returnType.name}${element.name.isEmpty?'':'.'}'
        '${element.name}(${papyrus.printParams(_ex.parameters)})');
    
    return buf.toString();
  }
}

class MethodHelper extends ExecutableHelper {
  MethodHelper(MethodElement element): super(element);
  
  String get typeName => 'Methods';
}

bool isStatic(PropertyInducingElement e) => e.isStatic();

bool isPrivate(Element e) => e.name.startsWith('_');

int elementCompare(Element a, Element b) => a.name.compareTo(b.name);
