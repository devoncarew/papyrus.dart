// Copyright (c) 2013, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/**
 * General String and dartdoc parsing untilities.
 */
library utils;

import 'dart:io';

abstract class CodeResolver {
  String resolveCodeReference(String reference);
}

String prettifyDocs(CodeResolver resolver, String docs) {
  if (docs == null) {
    return '';
  }

  docs = htmlEscape(docs);

  docs = stripComments(docs);

  StringBuffer buf = new StringBuffer();

  bool inCode = false;
  bool inList = false;

  for (String line in docs.split('\n')) {
    if (inList && !line.startsWith("* ")) {
      inList = false;
      buf.write('</ul>');
    }

    if (inCode && !(line.startsWith('    ') || line.trim().isEmpty)) {
      inCode = false;
      buf.write('</pre>');
    } else if (line.startsWith('    ') && !inCode) {
      inCode = true;
      buf.write('<pre>');
    } else if (line.trim().startsWith('* ') && !inList) {
      inList = true;
      buf.write('<ul>');
    }

    if (inCode) {
      if (line.startsWith('    ')) {
        buf.write('${line.substring(4)}\n');
      } else {
        buf.write('${line}\n');
      }
    } else if (inList) {
      buf.write('<li>${_processMarkdown(resolver, line.trim().substring(2))}</li>');
    } else if (line.trim().length == 0) {
      buf.write('</p>\n<p>');
    } else {
      buf.write('${_processMarkdown(resolver, line)} ');
    }
  }

  if (inCode) {
    buf.write('</pre>');
  }

  return buf.toString().replaceAll('\n\n</pre>', '\n</pre>').trim();
}

String htmlEscape(String text) {
  return text.replaceAll('&', '&amp;').
      replaceAll('>', '&gt;').replaceAll('<', '&lt;');
}

/**
 * [quoteType] should be ' or ".
 */
String stringEscape(String text, String quoteType) {
  return text.replaceAll(quoteType, "\\${quoteType}").
      replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t');
}

String escapeBrackets(String text) {
  return text.replaceAll('>', '_').replaceAll('<', '_');
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

File joinFile(Directory dir, List<String> files) {
  String pathFragment = files.join(Platform.pathSeparator);
  return new File("${dir.path}${Platform.pathSeparator}${pathFragment}");
}

Directory joinDir(Directory dir, List<String> files) {
  String pathFragment = files.join(Platform.pathSeparator);
  return new Directory("${dir.path}${Platform.pathSeparator}${pathFragment}");
}

String getBase(FileSystemEntity entity) {
  String name = entity.path;
  int index = name.lastIndexOf(Platform.pathSeparator);
  if (index != -1) {
    return name.substring(0, index);
  } else {
    return null;
  }
}

Directory getParent(Directory dir) {
  String base = getBase(dir);

  if (base == null) {
    return null;
  } else {
    return new Directory(base);
  }
}

String _processMarkdown(CodeResolver resolver, String line) {
  line = ltrim(line);

  if (line.startsWith("##")) {
    line = line.substring(2);

    if (line.endsWith("##")) {
      line = line.substring(0, line.length - 2);
    }

    line = "<h5>$line</h5>";
  } else {
    line = _replaceAll(line, ['[:', ':]'], htmlEntity: 'code');
    line = _replaceAll(line, ['`', '`'], htmlEntity: 'code');
    line = _replaceAll(line, ['*', '*'], htmlEntity: 'i');
    line = _replaceAll(line, ['__', '__'], htmlEntity: 'b');
    line = _replaceAll(line, ['[', ']'], replaceFunction: (String ref) {
      return resolver.resolveCodeReference(ref);
    });
  }

  return line;
}

String _replaceAll(String str, List<String> matchChars,
                   {String htmlEntity, var replaceFunction}) {
  int lastWritten = 0;
  int index = str.indexOf(matchChars[0]);
  StringBuffer buf = new StringBuffer();

  while (index != -1) {
    int end = str.indexOf(matchChars[1], index + 1);

    if (end != -1) {
      if (index - lastWritten > 0) {
        buf.write(str.substring(lastWritten, index));
      }

      String codeRef = str.substring(index + matchChars[0].length, end);

      if (htmlEntity != null) {
        buf.write('<$htmlEntity>$codeRef</$htmlEntity>');
      } else {
        buf.write(replaceFunction(codeRef));
      }

      lastWritten = end + matchChars[1].length;
    } else {
      break;
    }

    index = str.indexOf(matchChars[0], end + 1);
  }

  if (lastWritten < str.length) {
    buf.write(str.substring(lastWritten, str.length));
  }

  return buf.toString();
}
