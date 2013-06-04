
library papyrus_bin;

import 'dart:io';

import 'package:papyrus/papyrus.dart';

void main() {
  Papyrus papyrus = new Papyrus();
  
  if (papyrus.parseArgs(new Options().arguments)) {
    papyrus.generate();
  }
}
