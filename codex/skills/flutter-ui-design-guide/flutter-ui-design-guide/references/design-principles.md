# Flutter 디자인 핵심 원칙

## 철학

Flutter는 **크로스 플랫폼 일관성**과 **플랫폼별 적응**을 동시에 지원합니다.

## 핵심 원칙

### 1. 크로스 플랫폼 일관성
- 단일 코드베이스로 iOS/Android 동시 지원
- 픽셀 단위 동일한 UI

### 2. 플랫폼 적응 (Adaptive Design)
- Material Design (Android 스타일)
- Cupertino (iOS 스타일)
- 플랫폼 자동 감지

```dart
// 플랫폼별 위젯
Widget build(BuildContext context) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return CupertinoButton(child: Text('확인'), onPressed: () {});
  }
  return ElevatedButton(child: Text('확인'), onPressed: () {});
}
```

### 3. 위젯 트리 (Widget Tree)
- 모든 것이 위젯
- Composition over inheritance
- 재사용 가능한 컴포넌트

## Flexible 확장

### 4. 간결함
- 불필요한 요소 제거
- 명확한 위젯 계층

### 5. 접근성
- Semantics 위젯 사용
- 충분한 터치 영역 (최소 48x48dp)

## 권장 접근

- **Material 기본**: Material Design 3 위젯 사용
- **Cupertino 옵션**: iOS 스타일 필요 시 Cupertino 위젯
- **Adaptive 위젯**: 플랫폼 자동 감지

## 참고
- [Flutter Design](https://docs.flutter.dev/design)
- [Material Components](https://m3.material.io/)
- [Cupertino (iOS-style)](https://docs.flutter.dev/ui/widgets/cupertino)
