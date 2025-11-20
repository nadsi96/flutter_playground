
공식 사이트에서는
```
flutter pub add flutter_riverpod
flutter pub add dev:custom_lint
flutter pub add dev:riverpod_lint
```
로 안내하고 있으나
```
flutter pub add flutter_riverpod
```
얘만 실행해도 사용에 문제 없음   
$nbsp;
$nbsp;

## riverpod_lint/custom_lint
선택사항으로 제공되는 패키지로, 린트 규칙과 사용자 정의 리팩토링 옵션 제공   
analysis_options.yaml에 아래 내용 추가하라고 함
```
analyzer:
  plugins:
    - custom_lint
```