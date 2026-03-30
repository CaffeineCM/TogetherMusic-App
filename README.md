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

本项目分为两种接入方式：

- Web 部署：前端走相对路径，由 Nginx 反向代理 `/api/` 和 `/server/`
- 原生应用（macOS / Android）：通过 `--dart-define` 注入后端地址

Web 端不需要在代码里写死地址。

原生端运行示例：

```bash
flutter run -d macos \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket

flutter run -d android \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket
```

如果你的后端启用了 HTTPS / WSS，请把地址改成：

```bash
--dart-define=API_BASE_URL=https://your-host
--dart-define=WS_URL=wss://your-host/server/websocket
```

### 4. 运行项目

```bash
# Web
flutter run -d chrome

# macOS
flutter run -d macos \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket

# Windows
flutter run -d windows

# 移动端
flutter run \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket
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
flutter build macos \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket

# Windows
flutter build windows

# Android
flutter build apk \
  --dart-define=API_BASE_URL=http://your-host:your-port \
  --dart-define=WS_URL=ws://your-host:your-port/server/websocket

# iOS
flutter build ios
```

## Nginx 代理

`nginx.conf` 提供了 Web 部署示例，核心逻辑是：

- `/` 返回 Flutter Web 静态资源
- `/api/` 反向代理到后端 REST 服务
- `/server/` 反向代理到后端 STOMP / SockJS 端点

如果别人要替换后端地址，只需要：

1. Web 部署时修改 `nginx.conf` 里的 `proxy_pass`
2. 原生应用构建时修改 `--dart-define=API_BASE_URL=...` 和 `--dart-define=WS_URL=...`

## 相关项目

- [TogetherMusic-Server](https://github.com/CaffeineCM/TogetherMusic-Server) - 后端服务

## License

MIT
