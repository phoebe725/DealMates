// Lightweight i18n that mirrors the iOS app's model exactly: the English string
// IS the key. Translations are looked up per language; missing entries fall
// back to the English key. %@ / %lld placeholders are filled positionally.
//
// Seeded with the copy used by the shell, Discover and auth so far; more keys
// are added as screens are ported (values taken from Localizable.xcstrings).

export type Lang = "en" | "zh-Hans" | "zh-Hant";

const KEY = "preferredLanguageCode";

export function currentLang(): Lang {
  const stored = typeof localStorage !== "undefined" ? localStorage.getItem(KEY) : null;
  const raw = stored || (typeof navigator !== "undefined" ? navigator.language : "en");
  if (raw.startsWith("zh-Hans") || raw === "zh-CN" || raw === "zh") return "zh-Hans";
  if (raw.startsWith("zh-Hant") || raw === "zh-TW" || raw === "zh-HK") return "zh-Hant";
  if (raw.startsWith("zh")) return "zh-Hans";
  return "en";
}

export function setLang(l: Lang) {
  localStorage.setItem(KEY, l);
  window.location.reload();
}

const zhHans: Record<string, string> = {
  Discover: "发现",
  "My Plans": "我的饭局",
  Messages: "消息",
  Profile: "我的",
  "Find a ": "找人",
  Table: "拼桌",
  "Join dining plans nearby": "附近正在招募的饭局",
  Restaurants: "餐厅",
  Plans: "饭局",
  "Search restaurants or cuisine": "搜索餐厅或菜系",
  "All cuisines": "全部菜系",
  "My ": "我的",
  All: "全部",
  DMs: "私信",
  Featured: "精选",
  "All restaurants": "全部餐厅",
  "AYCE / Buffet": "自助餐 / 任食",
  Deal: "优惠",
  "Full": "已满",
  "%lld/%lld joined": "%lld/%lld 人已加入",
  "No active tables yet": "暂时没有招募中的饭局",
  "Start a table and find people to share a meal or deal.": "建立一个饭局，找人一起凑桌吃优惠。",
  "No restaurants yet": "暂时没有餐厅",
  "Finding restaurants nearby…": "正在查找附近的餐厅…",
  ASAP: "立刻",
  Weekday: "工作日",
  Weekend: "周末",
  Lunch: "午餐",
  Dinner: "晚餐",
  "Welcome back.": "欢迎回来",
  "Sign in to see your plans and chats.": "登录后查看你的饭局和聊天。",
  "Pin your first plan in a minute.": "一分钟，拼好你的第一桌",
  Email: "邮箱",
  Password: "密码",
  "At least 8 characters": "至少 8 个字符",
  "Sign in": "登录",
  "Sign up": "注册",
  "Pin me in": "把我拼进去",
  "Already have an account?": "已有账号？",
  "Don't have an account?": "还没有账号？",
  "Your name": "你的昵称",
  Loading: "加载中",
  "Find people to share group dining deals.": "找人拼桌，一起吃优惠。",
  // Plan detail / board / chat
  "Active plans": "进行中的饭局",
  "No active plans here yet": "这里还没有进行中的饭局",
  "Be the first to pin a plan.": "成为第一个发起饭局的人。",
  "Join this plan": "加入这个饭局",
  Leave: "离开",
  "Group is full": "人数已满",
  "Need %lld more": "差 %lld 人成团",
  "Your mates": "你的饭友",
  "Confirm attendance": "确认出席",
  "Add to calendar": "加入日历",
  "Added to calendar": "已加入日历",
  "Created %@": "创建于 %@",
  "Message…": "发消息…",
  Message: "发消息",
  Send: "发送",
  Share: "分享",
  "Create a table": "发起饭局",
  "No messages yet": "还没有消息",
  "Join a plan or message an organiser to start a thread.": "加入饭局或私信组织者，开启对话。",
  "Group · %lld/%lld": "群组 · %lld/%lld",
  "You.": "你。",
  "How your mates see you on PinTable.": "饭友眼中的你",
  "Edit profile": "编辑资料",
  Save: "保存",
  Cancel: "取消",
  Attendance: "出席",
  Hosted: "发起",
  "How it works": "使用方法",
  "Browse restaurants and see who's already planning to dine.": "浏览餐厅，看看谁已经在计划用餐。",
  "Pin a plan — set time, group size, and goal.": "发起一个饭局——设置时间、人数和目的。",
  "Chat in real-time with your mates before heading over.": "出发前与饭友实时聊天。",
  "Tell others a bit about yourself": "介绍一下你自己",
  "Sign out": "退出登录",
  Settings: "设置",
  // My Plans / Create / auth — match iOS catalog
  "plans.": "饭局",
  Active: "进行中",
  "Ready to go": "准备就绪",
  Completed: "吃过的饭局",
  "No plans yet": "还没有饭局",
  "Nothing ready to go yet": "还没有准备就绪的饭局",
  "No plans wrapped up yet": "还没有吃过的饭局",
  Done: "已完成",
  Ready: "准备好",
  "Welcome to the ": "欢迎",
  "table.": "入座",
  "I already have an account": "我已有账号",
  When: "时间",
  "Group size": "团体人数",
  "Open to": "接受",
  Anyone: "不限",
  Female: "女",
  Male: "男",
  "Notes (optional)": "备注（可选）",
  "Total needed": "总共需要",
  "Already joined": "已加入",
  Scheduled: "已安排",
  Flexible: "灵活",
  "%lld people": "%lld 人",
  "At %@.": "在 %@。",
  "e.g. Looking for 2 more for lunch deal": "例如：还差 2 人拼午市优惠",
  "Check your inbox": "查看你的收件箱",
  "I've verified my email": "我已验证邮箱",
  "Didn't receive an email?": "没收到邮件？",
  Resend: "重新发送",
  "Tap the link we sent to %@ to finish setting up your account.": "点击我们发送到 %@ 的链接，完成账号设置。",
};

const zhHant: Record<string, string> = {
  Discover: "探索",
  "My Plans": "我的飯局",
  Messages: "訊息",
  Profile: "我的",
  "Find a ": "找人",
  Table: "拼桌",
  "Join dining plans nearby": "附近正在招募的飯局",
  Restaurants: "餐廳",
  Plans: "飯局",
  "Search restaurants or cuisine": "搜尋餐廳或菜系",
  "All cuisines": "全部菜系",
  "My ": "我的",
  All: "全部",
  DMs: "私訊",
  Featured: "精選",
  "All restaurants": "全部餐廳",
  "AYCE / Buffet": "自助餐 / 任食",
  Deal: "優惠",
  "Full": "已滿",
  "%lld/%lld joined": "%lld/%lld 人已加入",
  "No active tables yet": "暫時沒有招募中的飯局",
  "Start a table and find people to share a meal or deal.": "建立一個飯局，找人一起湊桌吃優惠。",
  "No restaurants yet": "暫時沒有餐廳",
  "Finding restaurants nearby…": "正在尋找附近的餐廳…",
  ASAP: "立刻",
  Weekday: "平日",
  Weekend: "週末",
  Lunch: "午餐",
  Dinner: "晚餐",
  "Welcome back.": "歡迎回來",
  "Sign in to see your plans and chats.": "登入後查看你的飯局和聊天。",
  "Pin your first plan in a minute.": "一分鐘，拼好你的第一桌",
  Email: "電郵",
  Password: "密碼",
  "At least 8 characters": "至少 8 個字元",
  "Sign in": "登入",
  "Sign up": "註冊",
  "Pin me in": "把我拼進去",
  "Already have an account?": "已有帳號？",
  "Don't have an account?": "還沒有帳號？",
  "Your name": "你的暱稱",
  Loading: "載入中",
  "Find people to share group dining deals.": "找人拼桌，一起吃優惠。",
  "Active plans": "進行中的飯局",
  "No active plans here yet": "這裡還沒有進行中的飯局",
  "Be the first to pin a plan.": "成為第一個發起飯局的人。",
  "Join this plan": "加入這個飯局",
  Leave: "離開",
  "Group is full": "人數已滿",
  "Need %lld more": "差 %lld 人成團",
  "Your mates": "你的飯友",
  "Confirm attendance": "確認出席",
  "Add to calendar": "加入行事曆",
  "Added to calendar": "已加入行事曆",
  "Created %@": "建立於 %@",
  "Message…": "傳訊息…",
  Message: "傳訊息",
  Send: "傳送",
  Share: "分享",
  "Create a table": "發起飯局",
  "No messages yet": "還沒有訊息",
  "Join a plan or message an organiser to start a thread.": "加入飯局或私訊組織者，開啟對話。",
  "Group · %lld/%lld": "群組 · %lld/%lld",
  "You.": "你。",
  "How your mates see you on PinTable.": "飯友眼中的你",
  "Edit profile": "編輯資料",
  Save: "儲存",
  Cancel: "取消",
  Attendance: "出席",
  Hosted: "發起",
  "How it works": "使用方法",
  "Browse restaurants and see who's already planning to dine.": "瀏覽餐廳，看看誰已經在計劃用餐。",
  "Pin a plan — set time, group size, and goal.": "發起一個飯局——設定時間、人數和目的。",
  "Chat in real-time with your mates before heading over.": "出發前與飯友即時聊天。",
  "Tell others a bit about yourself": "介紹一下你自己",
  "Sign out": "登出",
  Settings: "設定",
  "plans.": "飯局",
  Active: "進行中",
  "Ready to go": "準備就緒",
  Completed: "吃過的飯局",
  "No plans yet": "還沒有飯局",
  "Nothing ready to go yet": "還沒有準備就緒的飯局",
  "No plans wrapped up yet": "還沒有吃過的飯局",
  Done: "已完成",
  Ready: "準備好",
  "Welcome to the ": "歡迎",
  "table.": "入座",
  "I already have an account": "我已有帳號",
  When: "時間",
  "Group size": "團體人數",
  "Open to": "接受",
  Anyone: "不限",
  Female: "女",
  Male: "男",
  "Notes (optional)": "備註（可選）",
  "Total needed": "總共需要",
  "Already joined": "已加入",
  Scheduled: "已安排",
  Flexible: "彈性",
  "%lld people": "%lld 人",
  "At %@.": "在 %@。",
  "e.g. Looking for 2 more for lunch deal": "例如：還差 2 人拼午市優惠",
  "Check your inbox": "查看你的收件匣",
  "I've verified my email": "我已驗證信箱",
  "Didn't receive an email?": "沒收到郵件？",
  Resend: "重新發送",
  "Tap the link we sent to %@ to finish setting up your account.": "點擊我們發送到 %@ 的連結，完成帳號設定。",
};

function dict(): Record<string, string> {
  const l = currentLang();
  return l === "zh-Hans" ? zhHans : l === "zh-Hant" ? zhHant : {};
}

/** Translate `key` (the English string), filling %@ / %lld placeholders. */
export function t(key: string, ...args: (string | number)[]): string {
  let s = dict()[key] ?? key;
  for (const a of args) s = s.replace(/%@|%lld|%1\$@|%2\$@/, String(a));
  return s;
}

const CUISINE_ZH_HANS: Record<string, string> = {
  "japanese / sushi": "日本料理 / 寿司",
  chinese: "中餐",
  "hot pot": "火锅",
  japanese: "日本料理",
  sichuan: "川菜",
  "hot pot / bbq": "火锅 / 烤肉",
  "ayce / buffet": "自助餐 / 任食",
  "northern chinese": "北方菜",
  "dim sum": "点心",
  cantonese: "粤菜",
  taiwanese: "台湾菜",
  "korean bbq": "韩式烤肉",
  korean: "韩国料理",
  vietnamese: "越南菜",
  thai: "泰国菜",
  indian: "印度菜",
  "sri lankan": "斯里兰卡菜",
  pakistani: "巴基斯坦菜",
  italian: "意大利菜",
  steakhouse: "牛排馆",
  burgers: "汉堡",
  "bubble tea": "珍珠奶茶",
};
const CUISINE_ZH_HANT: Record<string, string> = {
  "japanese / sushi": "日本料理 / 壽司",
  chinese: "中餐",
  "hot pot": "火鍋",
  japanese: "日本料理",
  sichuan: "川菜",
  "hot pot / bbq": "火鍋 / 烤肉",
  "ayce / buffet": "自助餐 / 任食",
  "northern chinese": "北方菜",
  "dim sum": "點心",
  cantonese: "粵菜",
  taiwanese: "台灣菜",
  "korean bbq": "韓式烤肉",
  korean: "韓國料理",
  vietnamese: "越南菜",
  thai: "泰國菜",
  indian: "印度菜",
  "sri lankan": "斯里蘭卡菜",
  pakistani: "巴基斯坦菜",
  italian: "義大利菜",
  steakhouse: "牛排館",
  burgers: "漢堡",
  "bubble tea": "珍珠奶茶",
};

// System chat messages (joins/leaves) — mirror ChatMessage.localizedSystemText.
const SYSTEM_TEMPLATES: Record<Lang, Record<string, string>> = {
  en: {
    joined: "%@ joined the plan 🙌",
    left: "%@ left the plan",
    left_promoted: "%1$@ left. %2$@ is now the organiser.",
    removed: "%1$@ removed %2$@ from the plan.",
  },
  "zh-Hans": {
    joined: "%@ 加入了饭局 🙌",
    left: "%@ 离开了饭局",
    left_promoted: "%1$@ 离开了。现由 %2$@ 担任组织者",
    removed: "%1$@ 将 %2$@ 移出了饭局",
  },
  "zh-Hant": {
    joined: "%@ 加入了飯局 🙌",
    left: "%@ 離開了飯局",
    left_promoted: "%1$@ 離開了。現由 %2$@ 擔任組織者",
    removed: "%1$@ 將 %2$@ 移出了飯局",
  },
};

export function systemMessageText(kind: string | null, args: string[] | null): string {
  if (!kind) return "";
  let s = SYSTEM_TEMPLATES[currentLang()][kind] ?? SYSTEM_TEMPLATES.en[kind] ?? "";
  (args ?? []).forEach((a, i) => {
    s = s.replace(`%${i + 1}$@`, a).replace("%@", a);
  });
  return s;
}

export function localizedCuisine(cuisine: string): string {
  const l = currentLang();
  const key = cuisine.toLowerCase();
  if (l === "zh-Hans") return CUISINE_ZH_HANS[key] ?? cuisine;
  if (l === "zh-Hant") return CUISINE_ZH_HANT[key] ?? cuisine;
  return cuisine;
}
