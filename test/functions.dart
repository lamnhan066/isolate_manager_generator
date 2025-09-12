import 'package:isolate_manager/isolate_manager.dart';
import 'package:isolate_manager_generator/src/utils.dart';

@isolateManagerWorker
void myWorkerFunction(String message) {
  printDebug(() => r'Received: $message');
}

@isolateManagerCustomWorker
void myCustomWorkerFunction(dynamic params) {
  printDebug(() => r'Custom worker processing: $params');
}

@isolateManagerSharedWorker
void mySharedWorkerFunction(dynamic params) {
  printDebug(() => r'Shared worker processing: $params');
}

class MyService {
  void regularMethod() {
    printDebug(() => 'This is a regular method.');
  }

  @isolateManagerWorker
  static void myWorkerMethod(int number) {
    printDebug(() => r'Processing number: $number');
  }

  @isolateManagerCustomWorker
  static void myCustomWorkerFunction(dynamic params) {
    printDebug(() => r'Custom worker processing: $params');
  }

  @isolateManagerSharedWorker
  static void mySharedWorkerFunction(dynamic params) {
    printDebug(() => r'Shared worker processing: $params');
  }
}

void anotherFunction() {
  printDebug(() => 'Not a worker.');
}
