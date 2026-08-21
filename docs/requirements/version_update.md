# 版本更新弹窗

## 目标

App 每次冷启动首次进入首页时，立即检查是否存在适用于当前设备的新版本。检查和弹窗不阻塞首页渲染。

## 接口

`GET /api/v1/app/configs/version/check`

接口使用项目统一响应结构，版本信息位于响应的 `data` 字段中。

请求参数：

| 参数 | 来源 |
| --- | --- |
| `current_version` | 安装包版本名 `PackageInfo.version` |
| `platform` | `ios` 或 `android` |
| `device_id` | 项目已有 `DeviceIdService` |
| `lang` | 当前系统语言代码，例如 `en`、`zh` |

弹窗使用的响应字段：

- `has_update`：决定是否展示。
- `latest_version`：用于版本说明。
- `update_type`：决定普通更新或强制更新。
- `release_notes`：最多展示前三条更新亮点。
- `market_url`：优先作为更新跳转地址。
- `download_url`：市场地址缺失时的回退地址。

`release_date` 不在弹窗中展示。`update_type` 的服务端约定为 `1=普通更新、2=强制更新`。

## 请求与弹出规则

1. 登录状态确认并首次进入 Home Tab 时立即异步请求。
2. 请求与首页首帧渲染并行，不等待首帧完成。
3. 每次冷启动最多请求一次；该标记仅保存在当前进程内。
4. 如果冷启动后首先进入 Shop Tab，则第一次切换至 Home Tab 时请求。
5. App 从后台恢复、首页重建、页面返回和重复切换 Tab 均不重复请求。
6. 请求失败时只记录日志，本次冷启动不再重试，也不展示错误提示。
7. 请求不显示全局 Loading，不阻塞首页交互。

## 弹窗内容

- 黄色圆形底上的 Nalo Logo。
- Title：`New version available`。
- Desc：说明升级价值，并弱化展示最新版本号。
- 最多三条更新亮点。
- 主按钮：`Update now`。
- 次操作：`Maybe later`，仅普通更新显示。

不展示发布日期、下载地址、设备、平台或灰度发布等技术字段。

## 更新类型

- 普通更新：允许点击遮罩关闭、返回键关闭或选择稍后更新。
- 强制更新：不可点击遮罩关闭，不响应返回关闭，仅保留立即更新按钮。
- 更新地址优先使用 `market_url`，缺失时使用 `download_url`。
