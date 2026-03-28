# SmartSleep Alarm · 智能睡眠闹铃

<p align="center">
  <strong>你睡，我响；你醒，我静；你再睡，我再响；你想赖床，打个响指。</strong>
</p>

---

## 📖 项目概述

SmartSleep Alarm 是一款 iOS + watchOS 智能闹铃应用，通过 Apple Watch 实时监测用户的睡眠状态，实现"睡着时闹铃持续响，醒了自动静音，持续确认用户不再睡回去，并支持手势贪睡"的核心体验。

### 核心特性

- 🧠 **智能静音**：检测到用户清醒后，闹铃在 5 秒内自动静音
- 🔄 **防再睡机制**：闹铃静音后持续监测 5 分钟，防止用户再次入睡
- 👋 **手势贪睡**：支持打响指或手腕翻转手势触发贪睡
- 📱 **跨平台同步**：iOS 与 watchOS 无缝数据同步
- 🔋 **低功耗设计**：后台监测耗电量 < 5%/小时

---

## 🏗️ 项目架构

```
SmartSleepAlarm/
├── SmartSleepAlarm/                    # iOS 应用目标
│   ├── Views/                          # 视图层
│   │   ├── AlarmListView.swift         # 闹铃列表主视图
│   │   ├── AlarmEditView.swift         # 闹铃创建/编辑视图
│   │   ├── PermissionOnboardingView.swift  # 权限引导视图
│   │   └── Components/
│   │       └── AlarmCardView.swift     # 闹铃卡片组件
│   ├── Services/                       # 服务层
│   │   ├── PermissionManager.swift     # 权限管理服务
│   │   └── WatchConnectivityManager.swift  # Watch 通信管理
│   ├── ContentView.swift               # 根视图
│   ├── SmartSleepAlarmApp.swift        # 应用入口
│   ├── Info.plist                      # 应用配置
│   └── SmartSleepAlarm.entitlements    # 权限配置
│
├── SmartSleepAlarmWatch/               # watchOS 应用目标
│   ├── Models/
│   │   └── AwakeDetectionConfig.swift  # 清醒检测配置
│   ├── Services/                       # 核心服务层
│   │   ├── SleepMonitorManager.swift   # 睡眠监测管理器
│   │   ├── AwakeDetectionService.swift # 清醒判断服务
│   │   ├── GestureDetectionService.swift   # 手势识别服务
│   │   ├── AlarmManager.swift          # 闹铃管理器
│   │   ├── AlarmPlayer.swift           # 闹铃播放器
│   │   ├── AlarmController.swift       # 闹铃控制器
│   │   ├── SensorService.swift         # 传感器服务
│   │   ├── BackgroundSessionManager.swift  # 后台会话管理
│   │   ├── SmartAlarmCoordinator.swift # 智能闹铃协调器
│   │   ├── PerformanceMonitor.swift    # 性能监控
│   │   ├── PerformanceOptimizer.swift  # 性能优化
│   │   └── WatchConnectivityManager.swift  # Watch 通信管理
│   ├── SmartSleepAlarmWatchApp.swift   # watchOS 应用入口
│   ├── Info.plist                      # watchOS 配置
│   └── SmartSleepAlarmWatch.entitlements  # watchOS 权限
│
├── Shared/                             # 共享代码
│   ├── Models/                         # 数据模型
│   │   ├── Alarm.swift                 # 闹铃核心模型
│   │   ├── Alarm+Codable.swift         # Alarm Codable 扩展
│   │   ├── AlarmSettings.swift         # 闹铃设置模型
│   │   ├── SleepData.swift             # 睡眠数据模型
│   │   ├── SleepState.swift            # 睡眠状态枚举
│   │   ├── SnoozeGesture.swift         # 贪睡手势枚举
│   │   ├── Ringtone.swift              # 铃声模型
│   │   ├── WatchMessage.swift          # Watch 通信消息
│   │   ├── SwiftDataConfig.swift       # SwiftData 配置
│   │   └── UserProfile.swift           # 用户配置模型
│   ├── ViewModels/
│   │   ├── AlarmManager.swift          # 闹铃业务逻辑管理
│   │   └── AlarmViewModel.swift        # 闹铃视图模型
│   ├── Services/
│   │   └── SharedDataManager.swift     # 共享数据管理器
│   └── Extensions/
│       ├── AppConstants.swift          # 应用常量
│       └── DateExtensions.swift        # 日期扩展
│
├── SmartSleepAlarmTests/               # iOS 单元测试
│   ├── AlarmTests.swift                # 闹铃模型测试
│   ├── AlarmSettingsTests.swift        # 闹铃设置测试
│   ├── SleepDataTests.swift            # 睡眠数据测试
│   ├── SharedDataManagerTests.swift    # 数据同步测试
│   └── WatchMessageTests.swift         # 通信消息测试
│
├── SmartSleepAlarmWatchTests/          # watchOS 测试
│   ├── AwakeDetectionConfigTests.swift # 清醒检测配置测试
│   ├── AwakeDetectionServiceTests.swift    # 清醒判断算法测试
│   ├── GestureDetectionServiceTests.swift  # 手势识别测试
│   ├── SensorServiceTests.swift        # 传感器服务测试
│   ├── BoundaryConditionTests.swift    # 边界条件测试
│   ├── Integration/                    # 集成测试
│   │   ├── MockServices.swift          # Mock 服务
│   │   ├── AlarmFlowIntegrationTests.swift
│   │   ├── SmartSilenceIntegrationTests.swift
│   │   ├── AntiSleepIntegrationTests.swift
│   │   ├── GestureSnoozeIntegrationTests.swift
│   │   ├── DegradedModeIntegrationTests.swift
│   │   └── StateTransitionIntegrationTests.swift
│   └── Performance/                    # 性能测试
│       ├── PerformanceTests.swift
│       └── PerformanceTestHelpers.swift
│
└── SmartSleepAlarm.xcodeproj/          # Xcode 项目文件
```

---

## 📦 功能模块详解

### 1. 闹铃管理模块（iOS 端）

#### AlarmListView - 闹铃列表视图
- 显示所有闹铃，按时间升序排序
- 支持闹铃开关切换
- 点击进入编辑页面
- 滑动删除闹铃

#### AlarmEditView - 闹铃编辑视图
- 时间选择器（DatePicker）
- 重复周期选择（周一至周日多选）
- 铃声选择（15 种系统铃声）
- 标签输入
- 智能模式开关
- 贪睡间隔设置（1-30 分钟）
- 贪睡手势选择

#### AlarmCardView - 闹铃卡片组件
- 大号时间显示
- 重复周期标签（工作日/周末/每天/自定义）
- 智能模式图标
- 启用状态边框高亮

### 2. 智能睡眠监测模块（watchOS 端）

#### SleepMonitorManager - 睡眠监测管理器
核心功能：
- 闹铃前 30 分钟自动启动后台监测
- 睡眠阶段检测（深睡、浅睡、REM、清醒）
- 最佳唤醒窗口识别
- 传感器状态监控

关键参数：
```swift
let monitorStartTime: Date          // 监测开始时间
let alarmTime: Date                 // 闹铃时间
let currentPhase: SleepPhase        // 当前睡眠阶段
let sensorStatuses: [SensorStatus]  // 传感器状态
```

#### SensorService - 传感器服务
数据采集：
- **心率数据**：通过 HealthKit 实时读取
- **加速度计数据**：通过 CoreMotion 采集
- **陀螺仪数据**：通过 CoreMotion 采集
- **HRV 数据**：心率变异性

采样配置：
```swift
struct SensorSamplingConfig {
    var accelerometerInterval: TimeInterval = 0.1  // 加速度计采样间隔
    var heartRateQueryInterval: TimeInterval = 5.0 // 心率查询间隔
    var motionUpdateInterval: TimeInterval = 0.1   // 运动数据更新间隔
}
```

#### BackgroundSessionManager - 后台会话管理
- 使用 `WKExtendedRuntimeSession` 保持后台运行
- 心跳机制防止系统终止
- 会话过期前通知

### 3. 清醒判断算法模块

#### AwakeDetectionService - 清醒判断服务

**算法流程：**
```
闹铃响起 → 开始监测 → 检测清醒信号 → 3秒确认窗口 → 闹铃静音 → 5分钟防再睡监测
```

**清醒信号检测：**
1. **心率信号**：心率比基准值高 10% 以上
2. **体动信号**：加速度计标准差 > 0.3
3. **组合信号**：心率 + 体动综合判断

**配置参数：**
```swift
struct AwakeDetectionConfig {
    var heartRateThresholdPercentage: Double = 0.10    // 心率阈值
    var motionThresholdStdDev: Double = 0.3            // 体动阈值
    var confirmationWindowSeconds: TimeInterval = 3.0  // 确认窗口
    var antiSleepMonitorDurationSeconds: TimeInterval = 300.0  // 防再睡时长
    var alarmSilenceMaxDelaySeconds: TimeInterval = 5.0  // 最大静音延迟
}
```

**三种预设模式：**
- `default`：默认模式
- `sensitive`：敏感模式（更容易触发）
- `conservative`：保守模式（更难触发）

### 4. 手势贪睡模块

#### GestureDetectionService - 手势识别服务

**支持的手势：**
1. **打响指**：
   - 加速度峰值 > 2.0g
   - 持续时间 < 0.5 秒
   - 检测双峰模式

2. **手腕翻转**：
   - 累积旋转角度 > 90°
   - 持续时间 < 1.0 秒
   - 检测旋转速率

**准确率保障：**
- 手势识别准确率 > 95%
- 误触发率 < 2%
- 1 秒冷却期防止连续触发

#### SnoozeManager - 贪睡管理
- 贪睡计时器（1-30 分钟可配置）
- 最多支持 3 次贪睡
- 震动反馈提示
- 贪睡期间继续睡眠监测

### 5. 闹铃播放控制模块

#### AlarmPlayer - 闹铃播放器

**播放模式：**
```swift
enum PlaybackMode {
    case standard      // 标准模式
    case fadeIn        // 渐强模式
    case snooze        // 贪睡模式
}
```

**功能特性：**
- 支持系统铃声和自定义铃声
- 音量控制（0.0 - 1.0）
- 渐强播放（从 0 渐变到目标音量）
- 手表震动同步

#### AlarmManager - 闹铃管理器（watchOS）

**状态管理：**
```swift
enum AlarmState {
    case idle                                    // 空闲
    case scheduled(nextAlarmTime: Date)          // 已计划
    case triggered(alarmId: UUID, triggerTime: Date)  // 闹铃中
    case snoozed(alarmId: UUID, snoozeEndTime: Date, snoozeCount: Int)  // 贪睡中
    case dismissed                               // 已关闭
}
```

### 6. iOS-watchOS 通信模块

#### WatchConnectivityManager - 通信管理器

**数据流向：**
| 方向 | 数据类型 | 传输方式 |
|------|---------|---------|
| iOS → watchOS | 闹铃数据 | `sendMessage` / `transferUserInfo` |
| iOS → watchOS | 贪睡设置 | `sendMessage` / `transferUserInfo` |
| watchOS → iOS | 闹铃触发状态 | `sendMessage` / `transferUserInfo` |
| watchOS → iOS | 闹铃关闭状态 | `sendMessage` / `transferUserInfo` |
| watchOS → iOS | 贪睡状态 | `sendMessage` / `transferUserInfo` |

**消息类型：**
```swift
enum WatchMessageType: String, Codable {
    case alarmDataSync       // 闹铃数据同步
    case alarmStateUpdate    // 闹铃状态更新
    case snoozeSettings      // 贪睡设置
    case requestSync         // 请求同步
    case ping                // 心跳
    case connectionStatus    // 连接状态
}
```

### 7. 权限管理模块

#### PermissionManager - 权限管理服务

**管理的权限：**
1. **HealthKit 权限**：
   - 读取：睡眠分析、心率、心率变异性
   - 写入：睡眠分析

2. **通知权限**：
   - 闹铃通知
   - 睡眠分析通知

**权限状态：**
```swift
enum PermissionStatus {
    case notDetermined    // 未决定
    case denied           // 已拒绝
    case authorized       // 已授权
    case partiallyAuthorized  // 部分授权
}
```

### 8. 性能优化模块

#### PerformanceMonitor - 性能监控

**监控指标：**
- 电池消耗率（目标 < 5%/小时）
- 平均响应时间（目标 < 5 秒）
- 手势识别准确率（目标 > 95%）
- CPU 使用率
- 内存使用量

**性能等级：**
```swift
enum PerformanceLevel {
    case excellent   // 优秀 - 所有指标达标
    case good        // 良好 - 2项达标
    case acceptable  // 可接受 - 1项达标
    case poor        // 较差 - 未达标但接近
    case critical    // 严重 - 严重偏离目标
}
```

#### PerformanceOptimizer - 性能优化

**优化配置：**
| 配置模式 | 传感器采样间隔 | 后台任务间隔 | 适用场景 |
|---------|--------------|------------|---------|
| `balanced` | 0.1秒 | 30秒 | 日常使用 |
| `batterySaver` | 0.2秒 | 60秒 | 低电量 |
| `highPerformance` | 0.05秒 | 15秒 | 需要快速响应 |
| `adaptive` | 动态调整 | 动态调整 | 自动优化 |

---

## 🔧 技术栈

| 技术 | 用途 |
|------|------|
| **Swift** | 开发语言 |
| **SwiftUI** | UI 框架 |
| **SwiftData** | 数据持久化 |
| **HealthKit** | 健康数据读取 |
| **CoreMotion** | 运动数据采集 |
| **WatchConnectivity** | iOS-watchOS 通信 |
| **WKExtendedRuntimeSession** | watchOS 后台运行 |
| **UNUserNotificationCenter** | 通知管理 |
| **XCTest** | 单元测试和集成测试 |

---

## 📱 系统要求

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+
- Apple Watch（支持心率监测）

---

## 🔐 权限配置

### iOS 端
- HealthKit（读取心率、睡眠数据）
- 通知权限
- 后台模式

### watchOS 端
- HealthKit（读取/写入心率、睡眠数据）
- 后台运行会话
- 运动数据访问

---

## 📊 性能指标

| 指标 | 目标值 | 实现方式 |
|------|--------|---------|
| 电池消耗 | < 5%/小时 | 自适应采样频率、省电模式 |
| 响应速度 | < 5 秒 | 后台任务优化、高性能模式 |
| 手势准确率 | > 95% | 多维度验证、置信度计算 |
| 误触发率 | < 2% | 严格阈值、冷却机制 |

---

## 🧪 测试覆盖

### 单元测试
- 闹铃数据模型测试
- 清醒判断算法测试
- 手势识别算法测试
- 数据同步测试

### 集成测试
- 完整闹铃流程测试
- 智能静音功能测试
- 防再睡功能测试
- 手势贪睡功能测试
- 降级策略测试

### 性能测试
- 电池消耗测试
- 响应时间测试
- 手势准确率测试

---

## 📄 许可证

本项目仅供学习和研究使用。

---

## 👥 贡献者

SmartSleep Alarm 开发团队

---

<p align="center">
  <strong>MVP Version 1.0</strong>
</p>
