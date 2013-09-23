// Copyright (c) 2013, Devon Carew. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library _papyrus_api;

import "dart:io";

import 'package:_internal/libraries.dart';
import '../lib/papyrus.dart' as papyrus;

void main() {
  String sdkPath = Platform.environment['DART_SDK'];

  papyrus.Papyrus generator = new papyrus.Papyrus();

  List<String> args = [];

  args.add('--out');
  args.add('docs');

  for (LibraryInfo library in LIBRARIES.values) {
    if (library.documented) {
      args.add("${sdkPath}/lib/${library.path}");
    }
  }

  if (generator.parseArgs(args)) {
    generator.generate();
  }
}
