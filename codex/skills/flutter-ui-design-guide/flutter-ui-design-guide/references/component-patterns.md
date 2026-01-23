# Flutter 컴포넌트 패턴

## 버튼

### Material
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('확인'),
)

OutlinedButton(
  onPressed: () {},
  child: Text('취소'),
)

TextButton(
  onPressed: () {},
  child: Text('건너뛰기'),
)
```

### Cupertino
```dart
CupertinoButton.filled(
  onPressed: () {},
  child: Text('확인'),
)
```

## 카드

```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(16.0),
    child: Column(
      children: [
        Text('제목', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8.0),
        Text('내용'),
      ],
    ),
  ),
)
```

## 리스트

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return ListTile(
      leading: Icon(Icons.star),
      title: Text(items[index].title),
      subtitle: Text(items[index].subtitle),
      trailing: Icon(Icons.arrow_forward_ios),
    );
  },
)
```

## 입력 필드

```dart
TextField(
  decoration: InputDecoration(
    labelText: '이메일',
    hintText: 'example@email.com',
  ),
)
```

## Navigation

### AppBar
```dart
Scaffold(
  appBar: AppBar(
    title: Text('제목'),
    actions: [
      IconButton(icon: Icon(Icons.add), onPressed: () {}),
    ],
  ),
  body: Container(),
)
```

### Bottom Navigation
```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
    BottomNavigationBarItem(icon: Icon(Icons.search), label: '검색'),
  ],
  onTap: (index) {},
)
```

## Dialog

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('제목'),
    content: Text('내용'),
    actions: [
      TextButton(child: Text('취소'), onPressed: () {}),
      TextButton(child: Text('확인'), onPressed: () {}),
    ],
  ),
)
```

## 참고
- [Material Widgets](https://docs.flutter.dev/ui/widgets/material)
- [Cupertino Widgets](https://docs.flutter.dev/ui/widgets/cupertino)
