import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class RiverpodCounterPage extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: _RiverpodCounterPage()
    );
  }

}

class _RiverpodCounterPage extends ConsumerWidget{
  Widget txtCounter(){
    return Consumer(builder: (context, ref, widget){
      print("Consumer build");
      // // final count = ref.watch(counterStateProvider);
      // final count = ref.watch(counterStateProvider2);
      // return Text("$count", style: const TextStyle(fontSize: 32));

      final countAsync = ref.watch(counterStateProvider3);
      return countAsync.when(
          data: (data) {
            return Text("$data", style: const TextStyle(fontSize: 32));
          },
          loading: () => Text("Loading..", style: TextStyle(fontSize: 32)),
          error: (err, stack) => Text("Error: $err")
      );
    });
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Provider 읽기 위해서는 ref 객체 필요
    // ref는 위젯, provider에서 provider를 읽을 수 있게 해줌
    // ref를 얻으려면 ConsumerWidget을 사용하거나, 사용하고 싶은 위젯 부분에서 Consumer 위젯으로 감싸야함
    // build 내에서 선언한 count는 ref의 watch로 counterStateProvider의 상태값 수신
    // 값이 변할때마다 감지되어 리빌드됨
    //  >> build 내에서 사용할 경우, text 뿐만 아니라 전체 화면이 갱신됨
    //  >> Consumer를 통해 해당 영역만 갱신될 수 있도록 작성
    // final count = ref.watch(counterStateProvider);
    print("CounterScreen build run");

    return Scaffold(
      body: Center(
        // child: Text('$count', style: const TextStyle(fontSize: 32))
          child: txtCounter()
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: (){
              // ref.read(counterStateProvider.notifier).increment();
              // ref.read(counterStateProvider2.notifier).increment();
              ref.read(counterStateProvider3.notifier).increment();
            },
          ),
          FloatingActionButton(
            child: const Icon(Icons.remove),
            onPressed: (){
              // ref.read(counterStateProvider.notifier).decrement();
              // ref.read(counterStateProvider2.notifier).decrement();
              ref.read(counterStateProvider3.notifier).decrement();
            },
          ),
        ],
      ),
    );
  }
}


/// Provider 정의 >>
/// int 타입의 counter에 대한 상태를 정의하는 StateNotifier 정의
/// StateNotifier/StateNotifierProvider는 초기 방식으로
/// 동기 방식이면 Notifier/NotifierProvider
/// 비동기 방식이면 AsyncNotifier/AsyncNotifierProvider로 구분하여 사용
/// Riverpod 2.0에서 추가됨
class CounterNotifier extends StateNotifier<int> {
  CounterNotifier(this.ref) : super(0);

  final Ref ref;

  Future<void> increment() async {
    state++;
  }
  Future<void> decrement() async {
    state--;
  }
}

final counterStateProvider = StateNotifierProvider<CounterNotifier, int>((ref){
  // ref 넘겨주는 이유
  // 기본적으로 StateNotifier에서는 제공되지 않음
  // >> StateNotifier 내부에서 다른 Provider에 접근할 수 없음
  // >> 다른 Provider에 접근 원할 경우 ref 전달해야함
  // >> 예시처럼 단순한 외부 의존성 없는 내용이라면 ref 전달 필요 없음
  // Notifier와 AsyncNotifier는 ref가 제공됨
  return CounterNotifier(ref);
});


class CounterNotifier2 extends Notifier<int> {

  @override
  int build() {
    // 초기값 지정
    return 0;
  }

  Future<void> increment() async {
    print("CounterNotifier2 increment");
    state++;
  }
  Future<void> decrement() async {
    print("CounterNotifier2 decrement");
    state--;
  }
}

final counterStateProvider2 = NotifierProvider<CounterNotifier2, int>((){
  return CounterNotifier2();
});


class CounterNotifier3 extends AsyncNotifier<int>{
  @override
  FutureOr<int> build() {
    return 0;
  }

  Future<void> increment() async {
    print("CounterNotifier3 increment");
    final current = state.value ?? 0;
    state = AsyncValue.data(current + 1);
  }
  Future<void> decrement() async {
    print("CounterNotifier3 decrement");
    final current = state.value ?? 0;
    state = AsyncValue.data(current - 1);
  }
}

final counterStateProvider3 = AsyncNotifierProvider<CounterNotifier3, int>( (){
  return CounterNotifier3();
});
/// << Provider 정의