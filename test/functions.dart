// This is a test file for isolate_manager annotations.
// ignore_for_file: avoid_print

import 'package:isolate_manager/isolate_manager.dart';

@isolateManagerWorker
void myWorkerFunction(String message) {
  print(r'Received: $message');
}

@isolateManagerCustomWorker
void myCustomWorkerFunction(dynamic params) {
  print(r'Custom worker processing: $params');
}

@isolateManagerSharedWorker
void mySharedWorkerFunction(dynamic params) {
  print(r'Shared worker processing: $params');
}

@isolateManagerWorker
@isolateManagerCustomWorker
@isolateManagerSharedWorker
void myMultiWorkersFunction(dynamic params) {
  print(r'Multi worker processing: $params');
}

class MyService {
  void regularMethod() {
    print('This is a regular method.');
  }

  @isolateManagerWorker
  static void myWorkerMethod(int number) {
    print(r'Processing number: $number');
  }

  @isolateManagerCustomWorker
  static void myCustomWorkerFunction(dynamic params) {
    print(r'Custom worker processing: $params');
  }

  @isolateManagerSharedWorker
  static void mySharedWorkerFunction(dynamic params) {
    print(r'Shared worker processing: $params');
  }

  @isolateManagerWorker
  @isolateManagerCustomWorker
  @isolateManagerSharedWorker
  static void myMultiWorkersFunction(dynamic params) {
    print(r'Multi worker processing: $params');
  }
}

void notAWorkerFunction() {
  print('Not a worker.');
}
