import 'package:grinder/grinder.dart';

main([List<String> args]) => grind(args);

@Task()
build() => run("./link.sh");
