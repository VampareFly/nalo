# AGENTS.md

# 项目说明

这是一个 Flutter 项目。

请遵循 Flutter 官方最佳实践，在保证功能正确的前提下，尽量保持代码简洁、可维护、符合 Flutter 开发习惯。

我的目标不仅是完成项目开发，也希望在开发过程中学习 Flutter，逐步建立 Flutter 的开发思维，而不是简单照搬 iOS 的开发方式。

---

# 开发规范

## 修改代码

- 仅修改完成当前需求所需的代码。
- 不要重构无关代码。
- 保持现有代码风格一致。
- 非必要不要修改已有逻辑。
- 如果发现更好的实现方案，先说明原因，再等待确认，不要直接修改。

---

# 学习模式（重要）

<!--我是一名有多年经验的 iOS 开发工程师，目前正在学习 Flutter。-->
<!---->
<!--完成需求时，不要只提供代码，请帮助我理解 Flutter。-->
<!---->
<!--具体要求：-->
<!---->
<!--- 说明为什么 Flutter 推荐这样实现。-->
<!--- 尽量与 iOS（UIKit / SwiftUI）进行对比，帮助我理解两者区别。-->
<!--- 如果使用了新的 Widget、API、状态管理或布局方式，请简单介绍其作用。-->
<!--- 如果存在多种实现方案，请说明优缺点，并推荐最佳实践。-->
<!--- 指出哪些写法属于 Flutter 思维，哪些是典型的 iOS 思维。-->
<!--- 当发现值得学习的知识点时，请主动补充，但避免过度展开，保持每次解释 3～10 分钟可以阅读完成。-->
<!---->
<!--如果我提出的问题属于 Flutter 基础，请优先采用教学方式，而不仅仅给出最终答案。-->

---

# 编译与测试

除非我明确要求，否则不要执行任何验证操作。

包括但不限于：

- flutter run
- flutter test
- flutter analyze
- dart test
- flutter build
- flutter pub upgrade
- Android Build
- iOS Build
- Xcode Build
- Gradle Build
- 启动模拟器
- 启动真机

完成代码修改后即可停止。

测试、运行、编译、验证均由我自己完成。

不要声称：

- 已测试
- 已验证
- 已编译成功
- 已运行通过

---

# 依赖管理

除非明确要求：

- 不要修改 pubspec.yaml
- 不要升级依赖
- 不要新增第三方库
- 不要修改 Flutter SDK Version

如果确实需要新增依赖：

请先说明：

- 为什么需要
- 是否有官方方案
- 是否有替代方案

等待确认后再修改。

---

# Flutter 开发规范

优先使用：

- Flutter 官方推荐方案
- Riverpod
- const Widget
- StatelessWidget（适用时）
- Widget 拆分
- Composition（组合优于继承）
- Extension
- Material 3

避免：

- 超长 build 方法
- Widget 嵌套过深
- 全局可变变量
- 不必要的 StatefulWidget
- 重复代码

---

# 状态管理

统一使用 Riverpod。

除非已有模块采用其他方案，否则不要引入新的状态管理框架。

编写 Riverpod 代码时：

- 优先采用官方推荐写法。
- 保持 Provider 单一职责。
- 避免 Provider 之间复杂依赖。

---

# UI

优先使用响应式布局。

推荐：

- Expanded
- Flexible
- LayoutBuilder
- MediaQuery（必要时）
- SafeArea

不要为了适配屏幕而写大量固定尺寸。

颜色、字体、圆角、间距优先使用项目已有 Design Token。

避免 Magic Number。

---

# 架构

业务逻辑不要写在 Widget 中。项目采用MVVM架构来做。

建议目录：

```
lib/
    pages/
    widgets/
    providers/
    services/
    repositories/
    models/
    utils/
```

遵循：

UI

↓

Provider

↓

Repository

↓

Service

保持各层职责清晰。

---

# 网络

不要直接在 Widget 中请求接口。

统一通过：

Repository → Service

处理网络请求。

---

# 国际化

<!--所有新增文案必须支持国际化。-->
<!---->
<!--不要直接写中文或英文字符串。-->

---

# 日志

不要新增 print。

统一使用项目已有 Logger。

---

# 性能

关注 Flutter Widget 重建。

优先：

- const
- Widget 拆分
- 合理使用 Consumer
- 避免不必要 rebuild

列表需要考虑：

- 懒加载
- 图片缓存
- Item 重建成本

---

# 注释

仅解释：

- 为什么这样实现
- 为什么采用当前方案
- 为什么不采用其他方案

不要写解释代码本身的注释。

---

# 其他


- 不完善的需求，要写todo, todo格式为 // TODO: <pf> 内容
- 
- 

不要写解释代码本身的注释。

---

# Git

不要执行任何 Git 操作。

包括：

- commit
- push
- pull
- merge
- rebase
- reset
- checkout
- 创建分支
- 修改 Git 历史

---

# 输出要求

完成任务后，请统一说明：

1. 修改了哪些文件。
2. 每个文件修改了什么。
3. 修改原因。
4. 对项目可能产生的影响。
5. 我可以重点学习哪些 Flutter 知识点。

如果有更好的实现方案，请额外说明，但不要直接修改。

不要声称已经：

- 编译成功
- 测试通过
- 验证完成
- 运行成功
