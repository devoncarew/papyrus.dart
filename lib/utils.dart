
/**
 * General String and dartdoc parsing untilities.
 */
library utils;

String prettifyDocs(String docs) {
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
      buf.write('<li>${_processMarkdown(line.trim().substring(2))}</li>');
    } else if (line.trim().length == 0) {
      buf.write('</p>\n<p>');
    } else {
      buf.write('${_processMarkdown(line)} ');
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

String _processMarkdown(String line) {
  // TODO: fix this - we need better markdown handling
  line = ltrim(line);
  
  if (line.startsWith("##")) {
    line = line.substring(2);
    
    if (line.endsWith("##")) {
      line = line.substring(0, line.length - 2);
    }
    
    line = "<h5>$line</h5>";
  } else {
    line = _replaceAll(line, ['[:', ':]'], 'code');
    line = _replaceAll(line, ['`', '`'], 'code');
    line = _replaceAll(line, ['*', '*'], 'i');
    line = _replaceAll(line, ['__', '__'], 'b');
    line = _replaceAll(line, ['[', ']'], 'a', 'code');
  }
  
  
  return line;
}

String _replaceAll(String str, List<String> matchChars, String htmlEntity, [String cssClass]) {
  int lastWritten = 0;
  int index = str.indexOf(matchChars[0]);
  StringBuffer buf = new StringBuffer();
  
  while (index != -1) {
    int end = str.indexOf(matchChars[1], index + 1);
    
    if (end != -1) {
      if (index - lastWritten > 0) {
        buf.write(str.substring(lastWritten, index));
      }
      
      if (cssClass == null) {
        buf.write('<$htmlEntity>');
      } else {
        buf.write('<$htmlEntity class=$cssClass>');
      }
      buf.write(str.substring(index + matchChars[0].length, end));
      buf.write('</$htmlEntity>');
      
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
