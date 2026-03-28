# SmartSleep Alarm 下一步工作流程

本文档详细说明 SmartSleep Alarm MVP 开发完成后的下一步工作流程，包括项目配置、测试、调试、优化和发布准备等环节。

---

## 📋 目录

1. [项目配置](#1-项目配置)
2. [开发者账号配置](#2-开发者账号配置)
3. [真机测试](#3-真机测试)
4. [功能验证](#4-功能验证)
5. [性能优化](#5-性能优化)
6. [Bug 修复流程](#6-bug-修复流程)
7. [发布准备](#7-发布准备)
8. [后续版本规划](#8-后续版本规划)

---

## 1. 项目配置

### 1.1 打开项目

```bash
# 在 Xcode 中打开项目
open /Users/lzc/TNTprojectZ/projectA/idea0320/SmartSleepAlarm/SmartSleepAlarm.xcodeproj
```

### 1.2 配置开发者团队

1. 在 Xcode 中选择项目导航器中的项目文件
2. 选择 `SmartSleepAlarm` 目标
3. 在 `Signing & Capabilities` 标签页中：
   - 选择你的开发者团队（Team）
   - 确保 Bundle Identifier 唯一
   - Xcode 会自动管理签名证书

4. 对 `SmartSleepAlarmWatch` 目标重复上述步骤

### 1.3 配置 App Groups

**在 Apple Developer Portal 中：**

1. 登录 [Apple Developer](https://developer.apple.com/account/)
2. 进入 `Certificates, Identifiers & Profiles`
3. 选择 `Identifiers` → 点击 `+` 创建新的 App Group
   - Identifier: `group.com.smartsleep.alarm`
   - Description: `SmartSleep Alarm App Group`

4. 编辑 iOS App ID，添加 App Groups capability
5. 编辑 watchOS App ID，添加 App Groups capability

**在 Xcode 中：**

1. 选择 `SmartSleepAlarm` 目标
2. 在 `Signing & Capabilities` 中点击 `+ Capability`
3. 添加 `App Groups`
4. 勾选 `group.com.smartsleep.alarm`
5. 对 `SmartSleepAlarmWatch` 目标重复上述步骤

### 1.4 配置 HealthKit

**在 Apple Developer Portal 中：**

1. 编辑 iOS App ID
2. 添加 HealthKit capability
3. 编辑 watchOS App ID
4. 添加 HealthKit capability

**在 Xcode 中：**

1. 选择目标 → `Signing & Capabilities`
2. 添加 `HealthKit` capability
3. 勾选必要的权限：
   - iOS: 读取心率、睡眠分析
   - watchOS: 读取和写入心率、睡眠分析

### 1.5 验证配置

```bash
# 检查 entitlements 文件
cat SmartSleepAlarm/SmartSleepAlarm.entitlements
cat SmartSleepAlarmWatch/SmartSleepAlarmWatch.entitlements
```

确保包含以下配置：
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.smartsleep.alarm</string>
</array>
<key>com.apple.developer.healthkit</key>
<true/>
```

---

## 2. 开发者账号配置

### 2.1 创建 App ID

| 平台 | Bundle ID | 说明 |
|------|-----------|------|
| iOS | `com.smartsleep.alarm` | iOS 应用 |
| watchOS | `com.smartsleep.alarm.watchkitapp` | watchOS 应用 |

### 2.2 创建 Provisioning Profiles

1. **开发证书**：
   - 创建 iOS Development 证书
   - 创建 watchOS Development 证书

2. **Provisioning Profiles**：
   - iOS App Development Profile
   - watchOS App Development Profile

3. **下载并安装**：
   - 在 Xcode → Preferences → Accounts 中刷新
   - 或手动下载并双击安装

### 2.3 配置测试设备

1. 在 Apple Developer Portal 中注册测试设备
2. 将设备 UDID 添加到 Provisioning Profile
3. 在 Xcode 中选择已注册的设备进行测试

---

## 3. 真机测试

### 3.1 准备测试设备

**iPhone 要求：**
- iOS 17.0 或更高版本
- 已登录 iCloud 账户
- 已配对 Apple Watch

**Apple Watch 要求：**
- watchOS 10.0 或更高版本
- 支持心率监测
- 电量充足（建议 > 50%）

### 3.2 安装应用到 iPhone

```bash
# 方式 1: 通过 Xcode 安装
# 1. 连接 iPhone 到 Mac
# 2. 在 Xcode 中选择 iPhone 作为运行目标
# 3. 点击 Run (Cmd + R)

# 方式 2: 通过 TestFlight 分发
# 1. 上传构建版本到 App Store Connect
# 2. 通过 TestFlight 邀请测试人员
```

### 3.3 安装应用到 Apple Watch

**自动安装：**
- iPhone 上安装应用后，watchOS 应用会自动安装到配对的 Apple Watch

**手动安装：**
1. 打开 iPhone 上的 Watch 应用
2. 滚动到"可用应用"
3. 找到 SmartSleep Alarm 并点击安装

### 3.4 首次启动配置

**iPhone 端：**
1. 启动应用
2. 完成权限引导：
   - 授权 HealthKit 权限
   - 授权通知权限
3. 创建第一个测试闹铃

**Apple Watch 端：**
1. 确保 iPhone 和 Apple Watch 蓝牙连接正常
2. 打开 SmartSleep Alarm 应用
3. 确认闹铃数据已同步

---

## 4. 功能验证

### 4.1 基础功能测试清单

#### 闹铃管理测试
- [ ] 创建新闹铃
- [ ] 编辑已有闹铃
- [ ] 删除闹铃
- [ ] 启用/禁用闹铃
- [ ] 闹铃列表正确排序
- [ ] 重复周期正确显示

#### 智能模式测试
- [ ] 开启智能模式
- [ ] 设置贪睡间隔
- [ ] 选择贪睡手势
- [ ] 设置保存成功

#### 数据同步测试
- [ ] iPhone 创建闹铃后 Watch 立即同步
- [ ] Watch 端闹铃状态同步到 iPhone
- [ ] 贪睡设置正确同步
- [ ] 断开重连后数据恢复

### 4.2 核心功能测试

#### 测试场景 1: 智能静音功能

**测试步骤：**
1. 创建一个 2 分钟后的闹铃
2. 开启智能模式
3. 等待闹铃响起
4. 保持清醒状态（心率正常、有轻微体动）
5. 观察闹铃是否在 5 秒内自动静音

**预期结果：**
- 闹铃响起后开始监测
- 检测到清醒信号后进入 3 秒确认窗口
- 确认后闹铃在 5 秒内静音

#### 测试场景 2: 防再睡功能

**测试步骤：**
1. 触发智能静音
2. 闹铃静音后立即躺下闭眼
3. 保持静止状态 1-2 分钟
4. 观察闹铃是否重新响起

**预期结果：**
- 闹铃静音后进入 5 分钟监测期
- 检测到再次入睡信号
- 闹铃自动重新响起

#### 测试场景 3: 手势贪睡功能

**测试步骤：**
1. 创建闹铃并开启手势贪睡
2. 选择贪睡手势（打响指或手腕翻转）
3. 闹铃响起后做出指定手势
4. 观察闹铃是否立即静音
5. 等待贪睡时间结束
6. 观察闹铃是否重新响起

**预期结果：**
- 手势识别成功
- 闹铃立即静音
- 显示贪睡提示（震动/图标）
- 贪睡时间到后闹铃重新响起

#### 测试场景 4: 传感器降级

**测试步骤：**
1. 创建闹铃并开启智能模式
2. 取下 Apple Watch 或遮挡传感器
3. 等待闹铃响起
4. 观察闹铃行为

**预期结果：**
- 检测到传感器数据缺失
- 自动降级为普通闹铃模式
- 闹铃正常响起直到手动关闭

### 4.3 性能测试

#### 电池消耗测试

**测试方法：**
```bash
# 1. 记录初始电量
# 2. 启动睡眠监测（闹铃前 30 分钟）
# 3. 运行 1 小时
# 4. 记录结束电量
# 5. 计算消耗率 = (初始电量 - 结束电量) / 小时
```

**目标：** < 5%/小时

#### 响应速度测试

**测试方法：**
1. 使用秒表测量从清醒到闹铃静音的时间
2. 多次测试取平均值

**目标：** < 5 秒

#### 手势准确率测试

**测试方法：**
1. 进行 100 次手势测试
2. 记录成功识别次数
3. 计算准确率 = 成功次数 / 总次数

**目标：** > 95%

---

## 5. 性能优化

### 5.1 使用 Instruments 分析

```bash
# 打开 Instruments
open -a Instruments

# 选择模板：
# 1. Time Profiler - CPU 使用分析
# 2. Allocations - 内存使用分析
# 3. Energy Log - 能耗分析
# 4.Leaks - 内存泄漏检测
```

### 5.2 优化建议

#### 电池优化
- 降低传感器采样频率（在保证功能的前提下）
- 使用自适应采样策略
- 减少后台任务频率
- 优化算法计算复杂度

#### 响应速度优化
- 预加载必要资源
- 优化算法执行效率
- 减少主线程阻塞
- 使用异步处理

#### 内存优化
- 及时释放不再使用的对象
- 避免循环引用
- 使用弱引用
- 优化数据结构

### 5.3 性能监控

**启用性能监控：**
```swift
// 在应用启动时
PerformanceMonitor.shared.startMonitoring()

// 定期检查性能指标
let metrics = PerformanceMonitor.shared.currentMetrics
print("电池消耗率: \(metrics.batteryDrainRate)")
print("响应时间: \(metrics.averageResponseTime)")
print("手势准确率: \(metrics.gestureAccuracy)")
```

---

## 6. Bug 修复流程

### 6.1 Bug 报告模板

```markdown
## Bug 标题
[简短描述 Bug]

## 复现步骤
1. 步骤一
2. 步骤二
3. 步骤三

## 预期行为
[描述预期的正确行为]

## 实际行为
[描述实际发生的错误行为]

## 环境信息
- iPhone 型号:
- iOS 版本:
- Apple Watch 型号:
- watchOS 版本:
- 应用版本:

## 截图/日志
[附上相关截图或日志]
```

### 6.2 调试技巧

#### 查看日志
```swift
// 在代码中添加日志
print("[SleepMonitor] 开始监测，闹铃时间: \(alarmTime)")
print("[AwakeDetection] 检测到清醒信号，置信度: \(confidence)")
print("[Gesture] 识别到手势: \(gestureType)")
```

#### 使用断点调试
1. 在 Xcode 中设置断点
2. 运行应用（Debug 模式）
3. 触发相关功能
4. 查看变量值和调用栈

#### 模拟传感器数据
```swift
// 在测试环境中模拟心率数据
sensorService.simulateHeartRate(75.0)

// 模拟运动数据
sensorService.simulateMotion(magnitude: 1.5)
```

### 6.3 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 闹铃不响 | 权限未授予 | 检查通知权限 |
| 数据不同步 | Watch 未连接 | 检查蓝牙连接 |
| 手势不识别 | 阈值过高 | 调整手势检测参数 |
| 电池消耗快 | 采样频率高 | 使用省电模式 |
| 应用崩溃 | 内存泄漏 | 使用 Instruments 检测 |

---

## 7. 发布准备

### 7.1 版本号管理

```swift
// 在 Info.plist 中设置版本号
CFBundleShortVersionString = "1.0.0"  // 用户可见版本号
CFBundleVersion = "1"                  // 构建号
```

### 7.2 App Store 资源准备

#### 应用截图
- iPhone: 6.7" (iPhone 14 Pro Max)、6.5" (iPhone 11 Pro Max)、5.5" (iPhone 8 Plus)
- Apple Watch: 不同的 watchOS 尺寸

#### 应用描述
```
SmartSleep Alarm 是一款智能睡眠闹铃应用，通过 Apple Watch 实时监测您的睡眠状态。

核心功能：
• 智能静音：醒来后闹铃自动静音
• 防再睡：监测您是否再次入睡
• 手势贪睡：打响指即可贪睡
• 低功耗：后台监测耗电 < 5%/小时

让每一个清晨都从温柔的唤醒开始。
```

#### 关键词
```
智能闹钟,睡眠监测,Apple Watch,健康,闹铃,贪睡,睡眠分析
```

### 7.3 上传构建版本

```bash
# 方式 1: 通过 Xcode 上传
# 1. Product → Archive
# 2. 选择构建版本
# 3. 点击 "Distribute App"
# 4. 选择 "App Store Connect"
# 5. 上传

# 方式 2: 通过命令行
xcodebuild -archivePath build/SmartSleepAlarm.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -exportArchive
```

### 7.4 TestFlight 测试

1. 上传构建版本到 App Store Connect
2. 添加测试人员
3. 分发测试版本
4. 收集反馈
5. 修复问题后重新上传

### 7.5 提交审核

**审核前检查清单：**
- [ ] 所有功能正常工作
- [ ] 无崩溃和严重 Bug
- [ ] 性能指标达标
- [ ] 隐私政策完善
- [ ] 应用截图完整
- [ ] 应用描述准确
- [ ] 版本号正确

**提交审核：**
1. 在 App Store Connect 中选择构建版本
2. 填写"此版本的新增内容"
3. 回答审核问卷
4. 点击"提交审核"

---

## 8. 后续版本规划

### 8.1 V1.1 版本计划

**新增功能：**
- 睡眠模式/小憩模式区分
- 睡眠数据统计和图表
- 贪睡次数限制
- 更多手势选项

**优化项：**
- 算法精度提升
- UI/UX 优化
- 性能进一步优化

### 8.2 V1.2 版本计划

**新增功能：**
- 语音播报（天气、每日一句）
- 睡眠记录分享
- 自定义铃声上传
- 多闹铃组管理

### 8.3 V2.0 版本计划

**重大更新：**
- 机器学习优化算法
- 多品牌手表支持
- 云端数据同步
- 家庭共享功能

---

## 📞 技术支持

如在开发过程中遇到问题，请按以下步骤排查：

1. 查阅本文档和相关代码注释
2. 检查 Xcode 控制台日志
3. 使用 Instruments 进行性能分析
4. 参考苹果官方文档：
   - [HealthKit Documentation](https://developer.apple.com/documentation/healthkit)
   - [WatchConnectivity Documentation](https://developer.apple.com/documentation/watchconnectivity)
   - [WKExtendedRuntimeSession Documentation](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession)

---

## 📝 更新日志

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| 1.0.0 | 2026-03-28 | MVP 版本发布 |

---

<p align="center">
  <strong>祝开发顺利！</strong>
</p>
