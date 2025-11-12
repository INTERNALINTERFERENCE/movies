# ViewSync Flutter App

Flutter приложение для синхронного просмотра видео в реальном времени.

## Функционал

- ✅ Экран входа с переключателем Join/Create Room
- ✅ WebSocket подключение к серверу
- ✅ Видео плеер с синхронизацией (play/pause/seek)
- ✅ Чат в реальном времени
- ✅ Список участников комнаты
- ✅ Отображение названия комнаты

## Установка

1. Убедитесь, что у вас установлен Flutter SDK
2. Установите зависимости:
```bash
flutter pub get
```

## Запуск

```bash
flutter run
```

## Структура проекта

```
lib/
├── main.dart                 # Точка входа
├── models/                  # Модели данных
│   ├── message_types.dart
│   ├── ws_message.dart
│   └── chat_message.dart
├── services/               # Сервисы
│   └── websocket_service.dart
├── screens/                # Экраны
│   ├── landing_screen.dart
│   └── room_screen.dart
└── widgets/               # Виджеты
    ├── video_player_widget.dart
    ├── participants_list.dart
    └── chat_widget.dart
```

## Настройка WebSocket

По умолчанию приложение подключается к `ws://localhost:8080/stream`. 
Измените URL в файле `lib/services/websocket_service.dart` при необходимости.

