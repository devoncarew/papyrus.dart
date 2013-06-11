
library model_utils;

import 'package:analyzer_experimental/src/generated/ast.dart';
import 'package:analyzer_experimental/src/generated/element.dart';
import 'package:analyzer_experimental/src/generated/engine.dart';
import 'package:analyzer_experimental/src/generated/constant.dart';
import 'package:analyzer_experimental/src/generated/java_io.dart';
import 'package:analyzer_experimental/src/generated/sdk.dart';
import 'package:analyzer_experimental/src/generated/sdk_io.dart';
import 'package:analyzer_experimental/src/generated/source_io.dart';

Element getOverriddenElement(Element element) {
  if (element is MethodElement) {
    return getOverriddenElementMethod(element as MethodElement);
  } else {
    // TODO: ctors, fields, accessors -

    return null;
  }
}

Object getConstantValue(PropertyInducingElement element) {
  if (element is ConstFieldElementImpl) {
    ConstFieldElementImpl e = element as ConstFieldElementImpl;
    return _valueFor(e.evaluationResult);
  } else if (element is ConstTopLevelVariableElementImpl) {
    ConstTopLevelVariableElementImpl e = element as ConstTopLevelVariableElementImpl;
    return _valueFor(e.evaluationResult);
  } else {
    return null;
  }
}

Object _valueFor(EvaluationResultImpl result) {
  if (result is ValidResult) {
    ValidResult r = result as ValidResult;

    return r.value;
  } else {
    return null;
  }
}

MethodElement getOverriddenElementMethod(MethodElement element) {
  ClassElement parent = element.enclosingElement;

  for (InterfaceType t in getAllSupertypes(parent)) {
    if (t.getMethod(element.name) != null) {
      return t.getMethod(element.name);
    }
  }

  return null;
}

bool canOverride(Element e) {
  return getEnclosingElement(e) != null;
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

List<InterfaceType> getAllSupertypes(ClassElement c) {
  InterfaceType t = c.type;

  return c.allSupertypes;

  // TODO:

  //return _getAllSupertypes(t, []);
}

//List<InterfaceType> _getAllSupertypes(InterfaceType type, List<InterfaceType> types) {
//
//  // TODO:
//
//  type.element.get
//  if (type == null || types.contains(type)) {
//    return types;
//  }
//
//  types.add(type);
//
//
//
//  return types;
//}
