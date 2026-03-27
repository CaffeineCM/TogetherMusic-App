# TogetherMusic App

一起听歌 - 前端应用 (Flutter)

## 技术栈

- **Flutter 3.11+**
- **Dart 3.11+**
- **Riverpod** - 状态管理
- **GoRouter** - 路由管理
- **Dio** - HTTP 客户端
- **STOMP** - WebSocket 通信

## 功能特性

- 🔐 用户注册/登录
- 🏠 创建/加入房间
- 🎵 搜索音乐 (网易云/QQ音乐/酷狗)
- 🎧 实时同步播放
- 📝 点歌/切歌投票
- 💬 房间聊天
- 👤 个人中心
- 🔗 音乐平台账号绑定

## 环境要求

- Flutter SDK 3.11.1+
- Dart SDK 3.11.1+

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/CaffeineCM/TogetherMusic-App.git
cd TogetherMusic-App
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 配置后端地址

修改 `lib/core/constants/app_constants.dart` 中的 API 地址：

```dart
static const String apiBaseUrl = 'http://localhost:8080';
static const String wsBaseUrl = 'ws://localhost:8080/ws';
```

### 4. 运行项目

```bash
# Web
flutter run -d chrome

# macOS
flutter run -d macos

# Windows
flutter run -d windows

# 移动端
flutter run
```

## 项目结构

```
lib/
├── core/
│   ├── constants/    # 常量配置
│   ├── models/       # 数据模型
│   ├── network/      # 网络请求
│   └── router/       # 路由配置
├── features/
│   ├── auth/         # 认证模块
│   ├── profile/      # 个人中心
│   └── room/         # 房间模块
└── main.dart         # 入口文件
```

## 构建发布

```bash
# Web
flutter build web

# macOS
flutter build macos

# Windows
flutter build windows

# Android
flutter build apk

# iOS
flutter build ios
```

## 相关项目

- [TogetherMusic-Server](https://github.com/CaffeineCM/TogetherMusic-Server) - 后端服务

## License

MIT
