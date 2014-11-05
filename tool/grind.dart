
import 'package:grinder/grinder.dart';

void main([List<String> args]) {
  task('init', init);
  task('build', build, ['init']);
  task('clean', clean);

  startGrinder(args);
}

void init(GrinderContext context) {
  // TODO:

}

void build(GrinderContext context) {
  runProcess(context, "./link.sh");
}

void clean(GrinderContext context) {
  // TODO:

}
