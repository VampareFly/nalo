/**
 * Nalo Shopify Custom Pixel → GA4。
 *
 * 使用方式：将本文件内容直接粘贴到 Shopify Admin → Settings →
 * Customer events → Add custom pixel 的 Code 区域，不要添加 <script> 标签。
 *
 * 数据流：Shopify Standard Customer Event → shopify_web_* GA4 自定义事件。
 * 身份流：URL / Checkout attributes → sessionStorage → GA4 用户身份与事件参数。
 *
 * 隐私要求：只读取下方显式映射的字段。禁止发送姓名、邮箱、手机号、完整地址、
 * 生日、IDFA、支付凭证、用户输入的告警值、完整错误信息和 URL Query。
 */

const GA4_MEASUREMENT_ID = 'G-WTW2GZ02Y6';
const DEBUG_MODE = true;
const EVENT_SCHEMA_VERSION = '1';
const EVENT_PLATFORM = 'shopify_web';

const JOURNEY_ID_KEY = 'nalo_journey_id';
const APP_USER_ID_KEY = 'nalo_app_user_id';
const ENTRY_SENT_KEY = 'nalo_app_entry_sent';

const APP_USER_ID_PARAMETER = 'app_user_id';
const JOURNEY_ID_PARAMETER = 'journey_id';

const MAX_EVENT_PARAMETERS = 25;
const MAX_ITEMS = 200;
const MAX_PARAMETER_STRING_LENGTH = 100;
const MAX_PAGE_LOCATION_LENGTH = 1000;
const MAX_USER_PROPERTY_STRING_LENGTH = 36;

// TODO: <pf> 发布正式店铺前替换为 Production Web Stream Measurement ID，并关闭 DEBUG_MODE。
// TODO: <pf> 确认服务端 URL 和 Cart/Checkout attributes 均使用 app_user_id、journey_id。

let configuredGa4UserId;
let eventQueue = Promise.resolve();

/** 初始化 Custom Pixel 独立使用的 GA4 发送器。 */
function initializeGa4() {
  window.dataLayer = window.dataLayer || [];

  window.gtag = function () {
    window.dataLayer.push(arguments);
  };

  const script = document.createElement('script');
  script.async = true;
  script.src =
    `https://www.googletagmanager.com/gtag/js?id=${GA4_MEASUREMENT_ID}`;
  document.head.appendChild(script);

  window.gtag('js', new Date());
  window.gtag('config', GA4_MEASUREMENT_ID, {
    send_page_view: false,
    debug_mode: DEBUG_MODE,
  });
}

/** 判断值是否可以作为 GA4 参数发送。 */
function hasValue(value) {
  return value !== null &&
    value !== undefined &&
    !(typeof value === 'string' && value.trim() === '');
}

/** 将 Shopify ID 等标量转为稳定字符串。 */
function toIdentifier(value) {
  if (!hasValue(value)) return undefined;
  return String(value).trim();
}

/** 将金额、数量等值安全转为有限 Number。 */
function toNumber(value) {
  if (!hasValue(value)) return undefined;
  const number = Number(value);
  return Number.isFinite(number) ? number : undefined;
}

/** 截断 GA4 字符串参数，避免超出平台长度限制。 */
function truncateString(value, maximumLength) {
  if (typeof value !== 'string') return value;
  return value.length > maximumLength
    ? value.slice(0, maximumLength)
    : value;
}

/** 清理一个 GA4 Item；只保留本文件显式构造的字段。 */
function cleanItem(item) {
  const cleaned = {};

  Object.entries(item || {}).forEach(([key, value]) => {
    if (!hasValue(value)) return;

    if (typeof value === 'string') {
      cleaned[key] = truncateString(
        value,
        MAX_PARAMETER_STRING_LENGTH,
      );
      return;
    }

    if (typeof value === 'number' && Number.isFinite(value)) {
      cleaned[key] = value;
      return;
    }

    if (typeof value === 'boolean') cleaned[key] = value;
  });

  return cleaned;
}

/** 清理事件参数中的空值并限制 items 数量。 */
function cleanEventParameters(parameters) {
  const cleaned = {};

  Object.entries(parameters || {}).forEach(([key, value]) => {
    if (!hasValue(value)) return;

    if (key === 'items') {
      if (!Array.isArray(value) || value.length === 0) return;
      const items = value
        .slice(0, MAX_ITEMS)
        .map(cleanItem)
        .filter((item) => Object.keys(item).length > 0);
      if (items.length > 0) cleaned.items = items;
      return;
    }

    if (typeof value === 'string') {
      const maximumLength = key === 'page_location'
        ? MAX_PAGE_LOCATION_LENGTH
        : MAX_PARAMETER_STRING_LENGTH;
      cleaned[key] = truncateString(value, maximumLength);
      return;
    }

    if (typeof value === 'number') {
      if (Number.isFinite(value)) cleaned[key] = value;
      return;
    }

    if (typeof value === 'boolean') {
      cleaned[key] = value;
    }
  });

  return cleaned;
}

/** 发送一个满足 Nalo 协议的 GA4 自定义事件。 */
function trackGa4Event(eventName, parameters = {}) {
  const cleanedParameters = cleanEventParameters(parameters);
  const parameterCount = Object.keys(cleanedParameters).length;

  if (parameterCount > MAX_EVENT_PARAMETERS) {
    console.error(
      '[Nalo GA4] Event skipped because parameter count exceeds 25:',
      eventName,
      parameterCount,
    );
    return;
  }

  if (DEBUG_MODE) {
    console.log('[Nalo GA4]', eventName, cleanedParameters);
  }

  window.gtag('event', eventName, cleanedParameters);
}

/**
 * 将 Shopify Customer GID 或数字 ID 归一化为 App 接口使用的 ID 部分。
 * 例如 gid://shopify/Customer/123 和 123 都会得到 123。
 */
function normalizeShopifyCustomerId(value) {
  const identifier = toIdentifier(value);
  if (!identifier) return undefined;

  if (identifier.includes('/')) {
    const segments = identifier.split('/').filter(Boolean);
    return segments[segments.length - 1];
  }

  return identifier;
}

/** 更新 GA4 系统 user_id；未知身份时不伪造 App User ID。 */
function setGa4UserId(shopifyCustomerId) {
  const normalizedId = normalizeShopifyCustomerId(shopifyCustomerId);
  const nextGa4UserId = normalizedId ?? null;

  if (configuredGa4UserId === nextGa4UserId) return;

  window.gtag('config', GA4_MEASUREMENT_ID, {
    send_page_view: false,
    debug_mode: DEBUG_MODE,
    user_id: nextGa4UserId,
  });

  configuredGa4UserId = nextGa4UserId;
}

/** 设置 Shopify Web 的 GA4 用户属性。 */
function setGa4UserProperties(linkContext, shopifyCustomerId) {
  window.gtag('set', 'user_properties', {
    app_user_id: linkContext.isAppLinked
      ? truncateString(
        linkContext.appUserId,
        MAX_USER_PROPERTY_STRING_LENGTH,
      )
      : null,
    shopify_login_state: shopifyCustomerId
      ? 'logged_in'
      : 'anonymous',
    app_linked_user: linkContext.isAppLinked ? 'yes' : 'no',
  });
}

/** 从 Shopify Attribute[] 中读取一个值。 */
function getAttributeValue(attributes, key) {
  if (!Array.isArray(attributes)) return undefined;
  const attribute = attributes.find((item) => item?.key === key);
  return toIdentifier(attribute?.value);
}

/** 验证 app_user_id 与 journey_id 是否同时存在。 */
function createValidLinkContext(appUserId, journeyId, source) {
  const normalizedAppUserId = toIdentifier(appUserId);
  const normalizedJourneyId = toIdentifier(journeyId);

  if (!normalizedAppUserId || !normalizedJourneyId) return undefined;

  return {
    appUserId: normalizedAppUserId,
    journeyId: normalizedJourneyId,
    isAppLinked: true,
    source,
  };
}

/** 从当前页面 URL 中读取 App Journey，不保留 Query。 */
function getLinkContextFromUrl(pageUrl) {
  if (!pageUrl) return undefined;

  try {
    const url = new URL(pageUrl);
    const appUserId = url.searchParams.get(APP_USER_ID_PARAMETER);
    const journeyId = url.searchParams.get(JOURNEY_ID_PARAMETER);
    const hasEitherParameter = hasValue(appUserId) || hasValue(journeyId);
    const context = createValidLinkContext(
      appUserId,
      journeyId,
      'url',
    );

    if (hasEitherParameter && !context) {
      console.warn(
        '[Nalo GA4] Ignored incomplete App Journey parameters in URL.',
      );
    }

    return context;
  } catch (_) {
    console.warn('[Nalo GA4] Ignored invalid page URL.');
    return undefined;
  }
}

/** 从 Cart 或 Checkout attributes 中恢复 App Journey。 */
function getLinkContextFromAttributes(attributes, source) {
  return createValidLinkContext(
    getAttributeValue(attributes, APP_USER_ID_PARAMETER),
    getAttributeValue(attributes, JOURNEY_ID_PARAMETER),
    source,
  );
}

/** 将一对有效 App Journey 标识写入当前浏览器会话。 */
async function persistLinkContext(linkContext) {
  if (!linkContext?.isAppLinked) return;

  await Promise.all([
    browser.sessionStorage.setItem(
      APP_USER_ID_KEY,
      linkContext.appUserId,
    ),
    browser.sessionStorage.setItem(
      JOURNEY_ID_KEY,
      linkContext.journeyId,
    ),
  ]);
}

/** 从当前浏览器会话中恢复一对 App Journey 标识。 */
async function getLinkContextFromSession() {
  const [appUserId, journeyId] = await Promise.all([
    browser.sessionStorage.getItem(APP_USER_ID_KEY),
    browser.sessionStorage.getItem(JOURNEY_ID_KEY),
  ]);

  return createValidLinkContext(
    appUserId,
    journeyId,
    'session_storage',
  );
}

/**
 * 按 URL → 当前事件 attributes → 初始化 Cart attributes → sessionStorage
 * 的优先级恢复 App Journey。
 */
async function resolveLinkContext(event, eventAttributes) {
  const pageUrl = event.context?.document?.location?.href;
  const urlContext = getLinkContextFromUrl(pageUrl);

  if (urlContext) {
    await persistLinkContext(urlContext);
    return {...urlContext, isIncomingFromUrl: true};
  }

  const eventAttributeContext = getLinkContextFromAttributes(
    eventAttributes,
    'event_attributes',
  );

  if (eventAttributeContext) {
    await persistLinkContext(eventAttributeContext);
    return {...eventAttributeContext, isIncomingFromUrl: false};
  }

  const initialCartContext = getLinkContextFromAttributes(
    init.data?.cart?.attributes,
    'initial_cart_attributes',
  );

  if (initialCartContext) {
    await persistLinkContext(initialCartContext);
    return {...initialCartContext, isIncomingFromUrl: false};
  }

  const sessionContext = await getLinkContextFromSession();
  if (sessionContext) {
    return {...sessionContext, isIncomingFromUrl: false};
  }

  return {
    appUserId: undefined,
    journeyId: undefined,
    isAppLinked: false,
    isIncomingFromUrl: false,
    source: 'standalone_web',
  };
}

/** 只返回不含 Query 和 Fragment 的页面地址。 */
function getSanitizedPageLocation(location) {
  if (!location) return undefined;

  if (location.origin && location.pathname) {
    return `${location.origin}${location.pathname}`;
  }

  if (!location.href) return undefined;

  try {
    const url = new URL(location.href);
    return `${url.origin}${url.pathname}`;
  } catch (_) {
    return undefined;
  }
}

/** 将页面路径归类为稳定的低基数 page_type。 */
function getPageType(pathname) {
  const path = pathname || '/';

  if (path === '/' || path === '') return 'home';
  if (/^\/products(?:\/|$)/.test(path)) return 'product';
  if (/^\/collections(?:\/|$)/.test(path)) return 'collection';
  if (/^\/search(?:\/|$)/.test(path)) return 'search';
  if (/^\/cart(?:\/|$)/.test(path)) return 'cart';
  if (/^\/checkouts?(?:\/|$)/.test(path)) return 'checkout';
  if (/^\/account(?:\/|$)/.test(path)) return 'account';
  if (/^\/(?:blogs|pages)(?:\/|$)/.test(path)) return 'content';
  return 'other';
}

/** 构造公共参数，并在业务事件发送前完成用户身份设置。 */
async function buildCommonParameters(
  event,
  eventAttributes,
  eventShopifyCustomerId,
) {
  const linkContext = await resolveLinkContext(event, eventAttributes);
  const location = event.context?.document?.location;
  const shopifyCustomerId = normalizeShopifyCustomerId(
    eventShopifyCustomerId || init.data?.customer?.id,
  );

  setGa4UserId(shopifyCustomerId);
  setGa4UserProperties(linkContext, shopifyCustomerId);

  const parameters = {
    event_schema_version: EVENT_SCHEMA_VERSION,
    event_platform: EVENT_PLATFORM,
    entry_source: linkContext.isAppLinked
      ? 'app'
      : 'standalone_web',
    shopify_event_id: toIdentifier(event.id),
    shopify_event_seq: toNumber(event.seq),
    shopify_client_id: toIdentifier(event.clientId),
    page_location: getSanitizedPageLocation(location),
    page_path: toIdentifier(location?.pathname),
    page_type: getPageType(location?.pathname),
    app_user_id: linkContext.isAppLinked
      ? linkContext.appUserId
      : undefined,
    journey_id: linkContext.isAppLinked
      ? linkContext.journeyId
      : undefined,
    shopify_customer_id: shopifyCustomerId,
  };

  return {linkContext, parameters};
}

/** 将 Shopify ProductVariant 转为统一 GA4 Item。 */
function buildItemFromVariant(variant, quantity = 1) {
  if (!variant) return undefined;

  const product = variant.product;
  const item = cleanItem({
    item_id: toIdentifier(variant.id),
    product_id: toIdentifier(product?.id),
    item_name: product?.title,
    item_variant: variant.title,
    item_brand: product?.vendor,
    item_category: product?.type,
    sku: variant.sku,
    price: toNumber(variant.price?.amount),
    quantity: toNumber(quantity),
  });

  return Object.keys(item).length > 0 ? item : undefined;
}

/** 将 Shopify CartLine 转为统一 GA4 Item。 */
function buildItemFromCartLine(cartLine) {
  if (!cartLine) return undefined;
  return buildItemFromVariant(cartLine.merchandise, cartLine.quantity);
}

/** 将 Shopify CheckoutLineItem 转为统一 GA4 Item。 */
function buildItemFromCheckoutLine(lineItem) {
  if (!lineItem) return undefined;

  const item = buildItemFromVariant(lineItem.variant, lineItem.quantity) || {};
  if (!item.item_id) item.item_id = toIdentifier(lineItem.id);
  if (!item.item_name) item.item_name = lineItem.title;

  const cleaned = cleanItem(item);
  return Object.keys(cleaned).length > 0 ? cleaned : undefined;
}

/** 映射数组并移除无法构造的 GA4 Item。 */
function buildItems(values, builder) {
  if (!Array.isArray(values)) return [];
  return values
    .slice(0, MAX_ITEMS)
    .map(builder)
    .filter(Boolean);
}

/** 从 Checkout 折扣中读取第一个折扣码。 */
function getCheckoutCoupon(checkout) {
  const discount = checkout?.discountApplications?.find(
    (application) => application?.type === 'DISCOUNT_CODE',
  );
  return discount?.title;
}

/** 构造所有 Checkout 步骤共用的业务参数。 */
function buildCheckoutParameters(checkout) {
  if (!checkout) return {};

  const lineItems = Array.isArray(checkout.lineItems)
    ? checkout.lineItems
    : [];
  const itemCount = lineItems.reduce(
    (total, lineItem) => total + (toNumber(lineItem?.quantity) || 0),
    0,
  );

  return {
    checkout_token: toIdentifier(checkout.token),
    item_count: itemCount,
    value: toNumber(checkout.totalPrice?.amount),
    currency: checkout.currencyCode || checkout.totalPrice?.currencyCode,
    discount_value: toNumber(checkout.discountsAmount?.amount),
    coupon: getCheckoutCoupon(checkout),
    items: buildItems(lineItems, buildItemFromCheckoutLine),
  };
}

/** 返回 Checkout 的第一笔交易，用于支付方式分类。 */
function getFirstTransaction(checkout) {
  return Array.isArray(checkout?.transactions)
    ? checkout.transactions[0]
    : undefined;
}

/** 返回 Checkout 当前选择的第一种配送方式。 */
function getSelectedDeliveryOption(checkout) {
  return Array.isArray(checkout?.delivery?.selectedDeliveryOptions)
    ? checkout.delivery.selectedDeliveryOptions[0]
    : undefined;
}

/** 判断搜索词是否疑似包含邮箱或电话号码。 */
function containsLikelyPersonalData(searchTerm) {
  if (!hasValue(searchTerm)) return false;
  const value = String(searchTerm);
  const hasEmail = /\b[^\s@]+@[^\s@]+\.[^\s@]+\b/i.test(value);
  const digitCount = (value.match(/\d/g) || []).length;
  const hasPhone = digitCount >= 7 && /^[\d\s()+\-.]+$/.test(value.trim());
  return hasEmail || hasPhone;
}

/** 统一保护异步事件回调，错误日志不输出原始 Shopify 数据。 */
function subscribeSafely(shopifyEventName, handler) {
  analytics.subscribe(shopifyEventName, (event) => {
    // sessionStorage 为异步 API，统一排队以保持 Shopify 事件到达顺序。
    eventQueue = eventQueue.then(() => handler(event)).catch((error) => {
      console.error(
        '[Nalo GA4] Failed to map Shopify event:',
        shopifyEventName,
        error?.name || 'UnknownError',
      );
    });
  });
}

initializeGa4();

subscribeSafely('page_viewed', async (event) => {
  const {linkContext, parameters} = await buildCommonParameters(event);

  if (linkContext.isIncomingFromUrl) {
    const sentJourneyId = await browser.sessionStorage.getItem(
      ENTRY_SENT_KEY,
    );

    if (sentJourneyId !== linkContext.journeyId) {
      await browser.sessionStorage.setItem(
        ENTRY_SENT_KEY,
        linkContext.journeyId,
      );
      trackGa4Event('shopify_web_app_entry', parameters);
    }
  }

  trackGa4Event('shopify_web_page_view', parameters);
});

subscribeSafely('collection_viewed', async (event) => {
  const collection = event.data?.collection;
  const {parameters} = await buildCommonParameters(event);
  const variants = Array.isArray(collection?.productVariants)
    ? collection.productVariants
    : [];

  trackGa4Event('shopify_web_collection_view', {
    ...parameters,
    collection_id: toIdentifier(collection?.id),
    collection_name: collection?.title,
    item_count: variants.length,
    items: buildItems(
      variants,
      (variant) => buildItemFromVariant(variant, 1),
    ),
  });
});

subscribeSafely('product_viewed', async (event) => {
  const variant = event.data?.productVariant;
  const {parameters} = await buildCommonParameters(event);

  trackGa4Event('shopify_web_product_view', {
    ...parameters,
    value: toNumber(variant?.price?.amount),
    currency: variant?.price?.currencyCode,
    items: variant
      ? [buildItemFromVariant(variant, 1)].filter(Boolean)
      : [],
  });
});

subscribeSafely('search_submitted', async (event) => {
  const searchResult = event.data?.searchResult;
  const {parameters} = await buildCommonParameters(event);
  const query = searchResult?.query;

  trackGa4Event('shopify_web_search', {
    ...parameters,
    search_term: containsLikelyPersonalData(query) ? undefined : query,
    result_count: Array.isArray(searchResult?.productVariants)
      ? searchResult.productVariants.length
      : undefined,
  });
});

subscribeSafely('product_added_to_cart', async (event) => {
  const cartLine = event.data?.cartLine;
  const amount = cartLine?.cost?.totalAmount;
  const {parameters} = await buildCommonParameters(event);

  trackGa4Event('shopify_web_add_to_cart', {
    ...parameters,
    value: toNumber(amount?.amount),
    currency: amount?.currencyCode,
    items: cartLine
      ? [buildItemFromCartLine(cartLine)].filter(Boolean)
      : [],
  });
});

subscribeSafely('product_removed_from_cart', async (event) => {
  const cartLine = event.data?.cartLine;
  const amount = cartLine?.cost?.totalAmount;
  const {parameters} = await buildCommonParameters(event);

  trackGa4Event('shopify_web_remove_from_cart', {
    ...parameters,
    value: toNumber(amount?.amount),
    currency: amount?.currencyCode,
    items: cartLine
      ? [buildItemFromCartLine(cartLine)].filter(Boolean)
      : [],
  });
});

subscribeSafely('cart_viewed', async (event) => {
  const cart = event.data?.cart;
  const totalAmount = cart?.cost?.totalAmount;
  const {parameters} = await buildCommonParameters(
    event,
    cart?.attributes,
  );

  trackGa4Event('shopify_web_cart_view', {
    ...parameters,
    cart_id: toIdentifier(cart?.id),
    item_count: toNumber(cart?.totalQuantity),
    value: toNumber(totalAmount?.amount),
    currency: totalAmount?.currencyCode,
    items: buildItems(cart?.lines, buildItemFromCartLine),
  });
});

subscribeSafely('checkout_started', async (event) => {
  const checkout = event.data?.checkout;
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
  );

  trackGa4Event('shopify_web_checkout_start', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
  });
});

subscribeSafely('checkout_contact_info_submitted', async (event) => {
  const checkout = event.data?.checkout;
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
  );

  trackGa4Event('shopify_web_checkout_contact_submit', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
    email_marketing_opt_in: checkout?.buyerAcceptsEmailMarketing,
    sms_marketing_opt_in: checkout?.buyerAcceptsSmsMarketing,
  });
});

subscribeSafely('checkout_address_info_submitted', async (event) => {
  const checkout = event.data?.checkout;
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
  );

  trackGa4Event('shopify_web_checkout_address_submit', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
    shipping_country_code: checkout?.shippingAddress?.countryCode,
  });
});

subscribeSafely('checkout_shipping_info_submitted', async (event) => {
  const checkout = event.data?.checkout;
  const deliveryOption = getSelectedDeliveryOption(checkout);
  const deliveryCost =
    deliveryOption?.costAfterDiscounts ?? deliveryOption?.cost;
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
  );

  trackGa4Event('shopify_web_checkout_shipping_submit', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
    shipping_tier: deliveryOption?.title,
    shipping_type: deliveryOption?.type,
    shipping_value: toNumber(
      deliveryCost?.amount ?? checkout?.shippingLine?.price?.amount,
    ),
  });
});

subscribeSafely('payment_info_submitted', async (event) => {
  const checkout = event.data?.checkout;
  const transaction = getFirstTransaction(checkout);
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
  );

  trackGa4Event('shopify_web_payment_info_submit', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
    payment_gateway: transaction?.gateway,
    payment_method: transaction?.paymentMethod?.name,
    payment_method_type: transaction?.paymentMethod?.type,
  });
});

subscribeSafely('checkout_completed', async (event) => {
  const checkout = event.data?.checkout;
  const transaction = getFirstTransaction(checkout);
  const orderCustomer = checkout?.order?.customer;
  const {parameters} = await buildCommonParameters(
    event,
    checkout?.attributes,
    orderCustomer?.id,
  );

  trackGa4Event('shopify_web_purchase', {
    ...parameters,
    ...buildCheckoutParameters(checkout),
    transaction_id: toIdentifier(checkout?.order?.id),
    tax: toNumber(checkout?.totalTax?.amount),
    shipping: toNumber(checkout?.shippingLine?.price?.amount),
    is_first_order: orderCustomer?.isFirstOrder,
    payment_gateway: transaction?.gateway,
    payment_method_type: transaction?.paymentMethod?.type,
  });
});

subscribeSafely('alert_displayed', async (event) => {
  const alert = event.data?.alert;
  const {parameters} = await buildCommonParameters(event);

  // alert.message 和 alert.value 可能包含用户输入，严禁发送。
  trackGa4Event('shopify_web_alert_display', {
    ...parameters,
    alert_type: alert?.type,
    alert_target: alert?.target,
  });
});

subscribeSafely('ui_extension_errored', async (event) => {
  const extensionError = event.data?.error;
  const {parameters} = await buildCommonParameters(event);

  // error.message 和 error.trace 可能包含敏感数据，严禁发送。
  trackGa4Event('shopify_web_ui_extension_error', {
    ...parameters,
    extension_app_id: toIdentifier(extensionError?.appId),
    extension_app_name: extensionError?.appName,
    extension_app_version: extensionError?.appVersion,
    extension_name: extensionError?.extensionName,
    extension_target: extensionError?.extensionTarget,
    extension_error_type: extensionError?.type,
  });
});
