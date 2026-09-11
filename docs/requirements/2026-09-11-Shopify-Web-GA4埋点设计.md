# Nalo Shopify Web GA4 埋点设计

## 基本信息

- 日期：2026-09-11
- 当前状态：设计与 Custom Pixel 初版已完成，待 Shopify / GA4 联调
- 数据来源：Shopify Customer Events / Web Pixels API
- 数据目标：Google Analytics 4 Shopify Web Stream
- 埋点协议版本：`1`
- 关联总规范：[Nalo GA4 跨端埋点设计](./2026-09-10-GA4跨端埋点设计.md)
- App 事件基准：[Nalo 客户端埋点设计](./2026-08-20-客户端埋点设计.md)
- Custom Pixel 代码：[Nalo Shopify Custom Pixel](./2026-09-11-Shopify-Custom-Pixel.js)

## 目标

本文是 Nalo Shopify Web 自定义埋点的第一准则，统一维护 Shopify 原始事件、Nalo GA4 自定义事件、公共参数、用户身份、用户属性、业务对象映射、隐私过滤、去重、会话恢复和验收规则。

当前目标：

- 监听 Shopify 当前提供的 15 个标准 Customer Events。
- 将标准 Customer Events 映射为独立的 `shopify_web_*` GA4 自定义事件。
- 事件名与 App 事件和 Google & YouTube 标准事件明确区分。
- App 来源访问持续携带 `app_user_id` 和 `journey_id`。
- 用户返回 Shopify 首页、浏览其他商品、进入购物车或继续结账时不丢失本次 Journey。
- App 与 Shopify Web 使用相同的 GA4 系统 `user_id` 规则。
- 商品、购物车、Checkout 和订单数据直接使用 Shopify 提供的值，只转换为 GA4 可分析的扁平结构。
- 强制排除个人信息、支付信息和其他不允许进入 GA4 的字段。

本文不负责：

- 修改 App 现有 Amplitude 事件和身份逻辑。
- 修改 Shopify 页面、购物车或 Checkout 的业务行为。
- 以浏览器 Pixel 事件代替 Shopify 订单 Webhook 和订单事实数据。
- 保证自定义事件自动进入 GA4 原生 Ecommerce 报表。

## 1. 整体工作流

```text
App 用户点击商品
  → Nalo 服务端生成 Shopify URL
  → URL 携带 app_user_id + journey_id
  → App 使用系统外部浏览器打开 Shopify
  → Shopify page_viewed
      ├─ 读取 URL 中的 app_user_id + journey_id
      ├─ 保存到 browser.sessionStorage
      ├─ 首次发送 shopify_web_app_entry
      └─ 发送 shopify_web_page_view
  → 后续 Shopify Customer Events
      ├─ 从 sessionStorage 恢复两个 ID
      ├─ 必要时从 Cart/Checkout attributes 兜底恢复
      ├─ 设置 Shopify Web GA4 用户身份和用户属性
      └─ 映射为 shopify_web_* 自定义事件
  → checkout_completed
      ├─ 关联 transaction_id
      ├─ 优先从 order.customer.id 取得 Shopify Customer ID
      └─ 发送 shopify_web_purchase
  → GA4 Exploration / BigQuery
```

Google & YouTube 标准事件与本文自定义事件可以并行存在：

| 数据层 | 事件名称 | 用途 |
|---|---|---|
| Google & YouTube 标准层 | `view_item`、`add_to_cart`、`purchase` 等 | GA4 原生 Ecommerce 报表和 Google Ads |
| Nalo Shopify Web 链路层 | `shopify_web_product_view`、`shopify_web_add_to_cart`、`shopify_web_purchase` 等 | App/Web 路径、身份和 Journey 分析 |

两层事件代表同一个业务动作时不得相加统计。若后续关闭 Google & YouTube 标准事件，自定义事件仍可用于 Exploration 和 BigQuery，但不会自动填充 GA4 原生 Ecommerce 报表。

## 2. 事件命名规则

Shopify Web 自定义事件统一使用：

```text
shopify_web_<业务动作>
```

命名要求：

- 全部小写。
- 只使用英文字母、数字和下划线。
- 不使用 GA4 保留前缀。
- 不复用 `page_view`、`view_item`、`purchase` 等 Google & YouTube 标准事件名。
- 事件名不得超过 GA4 的 40 字符限制。

## 3. 身份模型

| 身份 | App | Shopify Web | 用途 |
|---|---|---|---|
| Amplitude User ID | `AppUserInfo.id` | 不使用 | 保持 App 现有分析身份 |
| GA4 系统 `user_id` | `<shopify_customer_id>` | `<shopify_customer_id>` | 已知 Shopify Customer 的跨 Stream 身份 |
| `app_user_id` | GA4 用户属性 | GA4 用户属性及 App 来源事件参数 | 关联 Nalo App 后端用户 |
| `journey_id` | Shopify 跳转相关事件参数 | App 来源事件参数 | 关联一次 App → Shopify 购物旅程 |
| `shopify_client_id` | 不使用 | `event.clientId` | Shopify Web 匿名客户端排查 |
| `transaction_id` | 不使用 | `checkout.order.id` | 关联最终订单 |

### 3.1 GA4 系统 `user_id`

App 与 Shopify Web 统一格式：

`shopify_customer_id` 转为字符串后原样使用，不增加业务前缀。例如 Shopify Customer ID 为 `12345` 时，GA4 `user_id` 也是 `12345`。

Shopify Web 的 Customer ID 获取优先级：

```text
checkout.order.customer.id
  → init.data.customer.id
  → 无值时不设置 GA4 user_id
```

规则：

- App 的 GA4 `user_id` 继续使用接口用户信息中的 `shopify_customer_id`。
- Shopify 已登录或 Checkout 已能识别 Customer 时，使用相同格式设置 GA4 `user_id`。
- 不得使用 `app_user_id` 临时代替 GA4 `user_id`。
- 不得使用邮箱、姓名、手机号或其他可识别个人的信息构造 `user_id`。
- GA4 设置身份只影响设置后的事件，不保证回填之前的匿名事件。

### 3.2 Shopify Web 用户属性

Shopify Web 设置以下 GA4 用户属性：

| 用户属性 | 类型 | 规则 |
|---|---|---|
| `app_user_id` | String / null | App 来源时设置 App 后端用户 ID；无有效 App Journey 时清空 |
| `shopify_login_state` | String | `logged_in` 或 `anonymous` |
| `app_linked_user` | String | 当前有效 Journey 来自 App 时为 `yes`，否则为 `no` |

`entry_source` 不设置为用户属性。入口来源属于事件和 Journey，用户后续可能从其他渠道重新访问，设置为用户属性会覆盖历史语义。

`app_user_id` 可以发送为用户属性和事件参数，但不得注册为普通 GA4 自定义维度；精确身份查询使用 DebugView 或 BigQuery。

## 4. App Journey 参数与会话生命周期

### 4.1 Shopify URL

App 来源 Shopify URL 必须同时包含：

```text
app_user_id=<Nalo App 后端用户 ID>
journey_id=<本次购物旅程 ID>
```

示例：

```text
https://shop.example.com/products/example?app_user_id=123&journey_id=J100
```

两个参数必须成对出现。只有一个参数时视为无效 App Journey，不保存、不发送半条身份链路，并记录不包含用户资料的诊断日志。

### 4.2 sessionStorage

继续使用 Shopify Pixel 提供的 `browser.sessionStorage`，不使用 `localStorage` 和自定义 TTL。

| Key | 值 | 用途 |
|---|---|---|
| `nalo_journey_id` | 当前 `journey_id` | 恢复本次 App → Shopify Journey |
| `nalo_app_user_id` | 当前 `app_user_id` | 恢复 App 用户关联 |
| `nalo_app_entry_sent` | 已发送入口事件的 `journey_id` | 控制入口事件每个 Journey 只发送一次 |

生命周期规则：

1. 当前 URL 同时包含两个有效参数时，覆盖 sessionStorage 中的旧值。
2. 用户返回首页、浏览 Collection、查看其他商品、进入购物车或继续 Checkout 时不清除。
3. URL 不再包含参数时，从 sessionStorage 恢复。
4. Cart/Checkout attributes 同时存在两个参数时，可以作为兜底来源并回写 sessionStorage。
5. 新的 `journey_id` 表示新的 App Journey，覆盖旧 Journey 并允许重新发送入口事件。
6. 浏览器会话结束后由 sessionStorage 自然失效。
7. 纯 Web 访问且没有有效 sessionStorage 时，`entry_source` 为 `standalone_web`。

### 4.3 入口事件

`shopify_web_app_entry` 不是 Shopify 标准事件，而是基于 `page_viewed` 衍生的 Nalo GA4 自定义事件。

触发条件必须同时满足：

1. Shopify 触发 `page_viewed`。
2. 当前 URL 同时包含新的 `app_user_id` 和 `journey_id`。
3. `nalo_app_entry_sent` 尚未记录当前 `journey_id`。

同一个 Journey 返回首页或继续浏览时不重复发送入口事件，但后续事件继续携带两个 ID。

## 5. 公共事件参数

所有 `shopify_web_*` 事件统一使用以下公共参数：

| 参数 | 类型 | 来源 | 发送规则 | GA4 自定义定义 |
|---|---|---|---|---|
| `event_schema_version` | String | 固定 `1` | 始终发送 | 可注册事件级维度 |
| `event_platform` | String | 固定 `shopify_web` | 始终发送 | 注册事件级维度 |
| `entry_source` | String | Journey 判断 | `app` / `standalone_web` | 注册事件级维度 |
| `shopify_event_id` | String | `event.id` | 有值时发送 | 不注册 |
| `shopify_event_seq` | Number | `event.seq` | 有值时发送 | 不注册 |
| `shopify_client_id` | String | `event.clientId` | 有值时发送 | 不注册 |
| `page_location` | String | `origin + pathname` | 有页面上下文时发送 | 使用 GA4 页面字段 |
| `page_path` | String | `location.pathname` | 有页面上下文时发送 | 按报表需求注册 |
| `page_type` | String | 路径推导 | 始终发送 | 注册事件级维度 |
| `app_user_id` | String | URL / attributes / sessionStorage | App 来源时发送 | 不注册 |
| `journey_id` | String | URL / attributes / sessionStorage | App 来源时发送 | 不注册 |
| `shopify_customer_id` | String | Shopify Customer | 有值时发送 | 不注册 |

`page_type` 枚举：

```text
home
product
collection
search
cart
checkout
account
content
other
```

`page_location` 不包含 Query 和 Fragment，避免 `app_user_id`、`journey_id` 或其他查询参数进入 GA4 页面地址。

该清洗只影响 Custom Pixel 自己发送的 `shopify_web_*` 事件。Google & YouTube 应用发送的标准 `page_view` 不受本代码控制，因此还必须在 GA4 Web Stream 的 `Redact data` 中启用 URL Query Parameter Keys，并配置：

```text
app_user_id
journey_id
```

## 6. Shopify 公共业务对象映射

Shopify 原始对象作为数据源，不直接把嵌套的 `event.data`、`checkout`、`cart`、`cartLine` 或 `productVariant` 序列化发送给 GA4。

### 6.1 ProductVariant → GA4 Item

| Shopify 字段 | GA4 Item 参数 | 类型 | 规则 |
|---|---|---|---|
| `variant.id` | `item_id` | String | 统一使用 Shopify Variant ID |
| `variant.product.id` | `product_id` | String | 保留 Product 与 Variant 关系 |
| `variant.product.title` | `item_name` | String | 商品标题 |
| `variant.title` | `item_variant` | String | 规格标题 |
| `variant.product.vendor` | `item_brand` | String | Shopify Vendor |
| `variant.product.type` | `item_category` | String | Shopify Product Type |
| `variant.sku` | `sku` | String | 有值时发送 |
| `variant.price.amount` | `price` | Number | 单件价格 |
| 事件上下文数量 | `quantity` | Number | 商品浏览默认为 `1` |

商品数组统一使用：

```text
items[]
```

### 6.2 Cart → GA4 参数

| Shopify 字段 | GA4 参数 |
|---|---|
| `cart.id` | `cart_id` |
| `cart.totalQuantity` | `item_count` |
| `cart.cost.totalAmount.amount` | `value` |
| `cart.cost.totalAmount.currencyCode` | `currency` |
| `cart.lines[]` | `items[]` |

### 6.3 Checkout → GA4 参数

| Shopify 字段 | GA4 参数 |
|---|---|
| `checkout.token` | `checkout_token` |
| `checkout.lineItems[].quantity` 总和 | `item_count` |
| `checkout.totalPrice.amount` | `value` |
| `checkout.currencyCode` 或 `totalPrice.currencyCode` | `currency` |
| `checkout.discountsAmount.amount` | `discount_value` |
| 第一个 `DISCOUNT_CODE` 的 `title` | `coupon` |
| `checkout.lineItems[]` | `items[]` |

### 6.4 Order → Purchase 参数

| Shopify 字段 | GA4 参数 |
|---|---|
| `checkout.order.id` | `transaction_id` |
| `checkout.totalTax.amount` | `tax` |
| `checkout.shippingLine.price.amount` | `shipping` |
| `checkout.order.customer.isFirstOrder` | `is_first_order` |
| `checkout.transactions[0].gateway` | `payment_gateway` |
| `checkout.transactions[0].paymentMethod.type` | `payment_method_type` |

高基数 ID 可以发送并进入 BigQuery，但不注册普通 GA4 自定义维度。

## 7. Shopify 标准事件映射总表

| Shopify Customer Event | Nalo GA4 自定义事件 | Shopify 数据入口 | 主要业务参数 |
|---|---|---|---|
| `page_viewed` | `shopify_web_page_view` | `event.context` | 公共页面参数 |
| `collection_viewed` | `shopify_web_collection_view` | `data.collection` | `collection_id`, `collection_name`, `item_count`, `items` |
| `product_viewed` | `shopify_web_product_view` | `data.productVariant` | `value`, `currency`, `items` |
| `search_submitted` | `shopify_web_search` | `data.searchResult` | `search_term`, `result_count` |
| `product_added_to_cart` | `shopify_web_add_to_cart` | `data.cartLine` | `value`, `currency`, `items` |
| `product_removed_from_cart` | `shopify_web_remove_from_cart` | `data.cartLine` | `value`, `currency`, `items` |
| `cart_viewed` | `shopify_web_cart_view` | `data.cart` | `cart_id`, `item_count`, `value`, `currency`, `items` |
| `checkout_started` | `shopify_web_checkout_start` | `data.checkout` | Checkout 公共业务参数 |
| `checkout_contact_info_submitted` | `shopify_web_checkout_contact_submit` | `data.checkout` | Checkout 参数、营销订阅状态 |
| `checkout_address_info_submitted` | `shopify_web_checkout_address_submit` | `data.checkout` | Checkout 参数、`shipping_country_code` |
| `checkout_shipping_info_submitted` | `shopify_web_checkout_shipping_submit` | `data.checkout` | Checkout 参数、配送方式和配送金额 |
| `payment_info_submitted` | `shopify_web_payment_info_submit` | `data.checkout` | Checkout 参数、支付方式分类 |
| `checkout_completed` | `shopify_web_purchase` | `data.checkout` | Purchase 参数、`items` |
| `alert_displayed` | `shopify_web_alert_display` | `data.alert` | `alert_type`, `alert_target` |
| `ui_extension_errored` | `shopify_web_ui_extension_error` | `data.error` | Extension 标识和错误类型 |

额外衍生事件：

| 触发基础 | Nalo GA4 自定义事件 | 触发条件 | 参数 |
|---|---|---|---|
| `page_viewed` | `shopify_web_app_entry` | URL 首次携带一对新的 App Journey 参数 | 全部公共参数 |

## 8. 事件详细定义

### 8.1 页面和商品发现

| Nalo 事件 | 专属参数 | 规则 |
|---|---|---|
| `shopify_web_app_entry` | 无 | 每个新 `journey_id` 在当前会话只发送一次 |
| `shopify_web_page_view` | 无 | 所有 Shopify 页面均发送，不因 App 来源而跳过 |
| `shopify_web_collection_view` | `collection_id`, `collection_name`, `item_count`, `items` | Collection 商品使用统一 Item 结构 |
| `shopify_web_product_view` | `value`, `currency`, `items` | `items` 仅包含当前 ProductVariant |
| `shopify_web_search` | `search_term`, `result_count` | 搜索词疑似包含邮箱或手机号时不发送 `search_term` |

### 8.2 购物车

| Nalo 事件 | 专属参数 | 规则 |
|---|---|---|
| `shopify_web_add_to_cart` | `value`, `currency`, `items` | `value` 优先使用 `cartLine.cost.totalAmount.amount` |
| `shopify_web_remove_from_cart` | `value`, `currency`, `items` | 与加入购物车使用相同 Item 结构 |
| `shopify_web_cart_view` | `cart_id`, `item_count`, `value`, `currency`, `items` | 可从 `cart.attributes` 兜底恢复 Journey |

### 8.3 Checkout

以下事件都携带 Checkout 公共业务参数：

```text
checkout_token
item_count
value
currency
discount_value
coupon
items
```

| Nalo 事件 | 额外参数 | 规则 |
|---|---|---|
| `shopify_web_checkout_start` | 无 | 用户进入 Checkout 时发送 |
| `shopify_web_checkout_contact_submit` | `email_marketing_opt_in`, `sms_marketing_opt_in` | 只发送布尔状态，不发送联系方式 |
| `shopify_web_checkout_address_submit` | `shipping_country_code` | 只发送国家代码，不发送详细地址 |
| `shopify_web_checkout_shipping_submit` | `shipping_tier`, `shipping_type`, `shipping_value` | 优先使用 selected delivery option |
| `shopify_web_payment_info_submit` | `payment_gateway`, `payment_method`, `payment_method_type` | 只发送支付方式分类，不发送支付账号或凭证 |
| `shopify_web_purchase` | `transaction_id`, `tax`, `shipping`, `is_first_order`, `payment_gateway`, `payment_method_type` | Purchase 前优先使用订单 Customer ID 更新 GA4 `user_id` |

### 8.4 异常事件

| Nalo 事件 | 专属参数 | 禁止参数 |
|---|---|---|
| `shopify_web_alert_display` | `alert_type`, `alert_target` | 原始 `alert.value`、未经分类的完整 `message` |
| `shopify_web_ui_extension_error` | `extension_app_id`, `extension_app_name`, `extension_app_version`, `extension_name`, `extension_target`, `extension_error_type` | 完整 `message` 和 `trace` |

异常事件用于技术和体验排查，不计入核心购物漏斗。

## 9. 参数数量、空值和类型规则

- 每个 GA4 事件最多发送 25 个事件参数；设计和实现时公共参数与专属参数合并计数。
- `debug_mode` 通过 `gtag('config', GA4_MEASUREMENT_ID, { debug_mode: true })` 在测试配置中开启，不作为每个业务事件的参数发送，因此不占用 25 个参数名额；正式环境应关闭该配置。
- `null`、`undefined` 和空字符串不作为事件参数发送。
- 空的 `items` 不发送。
- 金额统一发送 Number，不发送带币种符号的字符串。
- ID 统一转为 String，避免不同事件出现 Number/String 类型漂移。
- 商品数量统一发送 Number。

当前设计按字段全部有值时预留的最大参数预算如下：

| 事件类型 | 公共参数 | 业务参数上限 | 合计上限 |
| --- | ---: | ---: | ---: |
| 页面、搜索、告警类 | 12 | 1～4 | 16 |
| 商品类 | 12 | 3～5 | 17 |
| 购物车类 | 12 | 5 | 17 |
| Checkout 步骤类 | 12 | 7～10 | 22 |
| `shopify_web_purchase` | 12 | 13 | 25 |

`shopify_web_purchase` 已达到上限。后续若增加购买参数，必须先删除、合并或转移现有参数，不能直接继续追加。
- 普通字符串按 GA4 长度限制截断；`page_location` 使用 GA4 页面地址限制。
- 不为了填满字段而发送默认空值。

## 10. 隐私与安全过滤

以下字段即使 Shopify 提供，也不得发送到 GA4：

```text
email
phone
smsMarketingPhone
firstName
lastName
fullName
address1
address2
city
zip
birth
IDFA / x-idfa
银行卡号
支付账号
支付凭证
alert.value
完整 error.message
error.trace
完整 URL Query 和 Fragment
```

补充规则：

- 不直接展开或序列化 `event.data`。
- 不直接发送完整 `checkout`、`cart`、`cartLine`、`productVariant` 或地址对象。
- 搜索词命中邮箱或电话号码特征时不发送原始值。
- Alert 和 Extension Error 只发送稳定分类，不发送用户输入或完整堆栈。
- `app_user_id` 和 `journey_id` 仅用于分析，不得用于身份认证、权限判断或交易授权。

## 11. Cart / Checkout / Order attributes

为了在 Checkout、订单和服务端数据中保留 App Journey，Cart/Checkout/Order attributes 需要同时包含：

```text
app_user_id
journey_id
```

职责边界：

| 组件 | 职责 |
|---|---|
| App / Nalo 服务端 / Shopify Cart 业务逻辑 | 将两个字段写入 Cart/Checkout/Order attributes |
| Shopify Custom Pixel | 读取 attributes，恢复 sessionStorage，并附加到自定义事件 |
| Shopify 订单 Webhook / 服务端 | 读取订单 attributes，关联 App 用户、Journey、Customer 和订单 |

Custom Pixel 不承担修改购物车或订单的业务职责。若当前链路只能透传 `app_user_id`，需要同步增加 `journey_id`，否则只能关联用户，不能精确区分该用户的多次购物旅程。

## 12. 可靠性和去重

- 普通业务事件遵循 Shopify Customer Event 的触发次数，不额外按商品或页面去重。
- `shopify_web_app_entry` 使用 `nalo_app_entry_sent` 按 `journey_id` 去重。
- `shopify_event_id` 用于排查同一个 Shopify 事件是否被重复映射或重复发送。
- `shopify_event_seq` 仅辅助观察事件顺序，不作为全局唯一标识。
- Custom Pixel 内部按 Shopify 事件到达顺序串行处理异步回调，避免 `sessionStorage` 读写使入口事件晚于后续商品事件。
- `transaction_id` 用于 Purchase 和订单数据关联。
- Pixel 可能因 Consent、广告拦截、网络中断、页面快速关闭或完成页未加载而缺失事件。
- `shopify_web_purchase` 不作为订单事实的唯一来源，最终订单数量、退款、取消和订单修改以 Shopify 服务端数据为准。

## 13. GA4 后台与 BigQuery

建议注册以下低基数自定义定义：

| 字段 | Scope |
|---|---|
| `event_schema_version` | Event |
| `event_platform` | Event |
| `entry_source` | Event |
| `page_type` | Event |
| `shopify_login_state` | User |
| `app_linked_user` | User |

以下高基数字段正常发送，但不注册普通自定义维度：

```text
app_user_id
journey_id
shopify_customer_id
shopify_client_id
shopify_event_id
cart_id
checkout_token
transaction_id
```

数据查看边界：

- GA4 Reports / Explorations：查看聚合事件、来源比较和购物漏斗。
- DebugView：查看测试设备当前事件参数和用户属性。
- BigQuery：按 `app_user_id`、`journey_id`、GA4 `user_id` 和 `transaction_id` 查询完整用户路径。

## 14. 实现职责

Custom Pixel 实现应按以下职责拆分函数：

```text
initializeGa4
  → 初始化独立 GA4 发送器、关闭自动 page_view，并按环境配置 Debug

resolveLinkContext
  → URL / attributes / sessionStorage 恢复 App Journey

buildCommonParameters
  → 构造公共参数并设置身份、用户属性

buildItemFromVariant / CartLine / CheckoutLine
  → 转换统一 items 结构

buildCheckoutParameters
  → 提取 Checkout 公共业务参数

trackGa4Event
  → 清理空值、校验事件参数不超过 25 个并发送

analytics.subscribe
  → 订阅 Shopify 事件并调用对应映射
```

Measurement ID、Debug Mode 和环境切换不得散落在每个事件回调中。

## 15. 验收场景

| 场景 | 预期结果 |
|---|---|
| App 打开商品页 | 发送一次 `shopify_web_app_entry`，并发送页面和商品事件 |
| App 打开商品后返回首页 | 不重复入口事件；首页事件继续带两个 Journey 参数 |
| App 打开商品后购买其他商品 | 后续商品、购物车和 Checkout 事件继续使用原 Journey |
| 同一用户发起新的 Journey | 覆盖旧 sessionStorage，并允许发送新的入口事件 |
| 纯 Web 访问 | `entry_source=standalone_web`，不发送两个 App ID |
| URL 只有一个 App 参数 | 不保存半条链路，按无效 Journey 处理 |
| Shopify 用户已登录 | GA4 `user_id=<shopify_customer_id>` |
| Shopify 用户未登录 | 不设置 GA4 `user_id`，仍可通过 App Journey 关联事件 |
| Guest Checkout 最终取得 Customer ID | Purchase 前使用订单 Customer ID 设置 GA4 `user_id` |
| Cart/Checkout attributes 有两个 Journey 参数 | 从 attributes 恢复并回写 sessionStorage |
| 搜索词包含邮箱或手机号 | 发送搜索事件，但不发送原始 `search_term` |
| Alert 包含用户输入值 | 只发送 `alert_type` 和 `alert_target` |
| Purchase 页面未加载 | 允许 Pixel Purchase 缺失，由订单 Webhook 兜底 |
| 用户未授予 Analytics Consent | 不绕过 Shopify Customer Privacy 强制采集 |

## 16. 当前待办

```text
// TODO: <pf> 确认 Shopify URL 接口稳定返回并透传 app_user_id 与 journey_id。
// TODO: <pf> 确认 Cart/Checkout/Order attributes 同时写入两个 Journey 字段。
// TODO: <pf> 在 GA4 Web Stream 的 Redact data 中删减 app_user_id、journey_id URL 参数。
// TODO: <pf> 在 Test GA4 Property 中完成 15 个标准事件与入口衍生事件联调。
// TODO: <pf> 配置 GA4 BigQuery Export 后补充标准 Journey 查询。
// TODO: <pf> 正式发布前关闭 Custom Pixel debug_mode。
```

## 17. 维护规则

新增或修改 Shopify Web 事件时：

1. 先记录原始 Shopify Customer Event 和准确触发时机。
2. 使用唯一 `shopify_web_*` 自定义事件名。
3. 优先复用本文公共参数和公共业务对象映射。
4. 统计公共参数与专属参数总数，不得超过 GA4 限制。
5. 检查是否包含个人信息、用户输入、支付信息或高基数字段。
6. 同步检查 Cart/Order attributes 和 BigQuery 关联字段。
7. 若修改身份、环境或 App/Web 共用字段，同时更新《Nalo GA4 跨端埋点设计》。

本文不替代 App 客户端埋点设计。App 事件名称、业务参数和触发时机继续以《Nalo 客户端埋点设计》为准。
