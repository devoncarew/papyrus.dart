
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
      // TODO: less ws or more?
      buf.write('</p><p>'); //buf.write('<br>');
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
