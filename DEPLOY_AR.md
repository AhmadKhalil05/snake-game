# نشر Snake: Neon Runner على GitHub وCloudflare Pages

الحزمة تحتوي ملفات Lua الأصلية ونسخة متصفح جاهزة داخل `web`.
لا تحتاج Node.js لتنفّذ أول نشر بهذه الحزمة. لا ترفع ملف ZIP نفسه إلى GitHub؛
فك ضغطه وارفع الملفات والمجلدات الموجودة داخله.

## 1. GitHub

1. افتح https://github.com/new وسجّل دخولك.
2. اسم المستودع المقترح: `snake-neon-runner`.
3. اختر Public إذا بدك رابط الكود ظاهر للدكتور. اتبع شروط المساق إذا طلب خصوصية.
4. فعّل Add a README file ثم Create repository.
5. من صفحة المستودع اختَر Add file ثم Upload files.
6. افتح مجلد `Snake_Neon_Runner_DEPLOY` عندك، وحدد **محتوياته** واسحبها لصفحة الرفع.
7. اكتب `Add Snake game and web build` ثم Commit changes إلى فرع `main`.

بعد الرفع لازم ترى `main.lua` و`states` و`web` و`DEPLOY_AR.md` مباشرة في الصفحة
الرئيسية للمستودع. داخل `web` لازم يوجد `index.html` و`game.js` و`game.data`
و`love.js` و`love.wasm` و`player.js` و`player.css`.

لا ترفع المجلد الخارجي كله تحت مجلد إضافي داخل المستودع؛ الإعدادات الآتية
تفترض أن `web` مباشرة في جذر المستودع.

## 2. Cloudflare Pages

1. افتح https://dash.cloudflare.com وسجّل دخولك.
2. ادخل Workers & Pages ثم Create application.
3. اختر Pages ثم Connect to Git، أو Import an existing Git repository بحسب الواجهة.
4. اختر GitHub واربط الحساب. إذا ظهر اختيار صلاحيات المستودعات، اختر المستودع المطلوب.
5. اختر `snake-neon-runner` ثم Begin setup.
6. املأ الإعدادات التالية:

| الحقل | القيمة |
| --- | --- |
| Project name | snake-neon-runner، أو اسم متاح تختاره |
| Production branch | main |
| Framework preset | None |
| Build command | exit 0 |
| Build output directory | web |
| Root directory | اتركه فارغاً |
| Environment variables | اتركها فارغة |

7. اضغط Save and Deploy وانتظر نجاح النشر.
8. افتح رابط `pages.dev` الذي يرجعه Cloudflare. هذا هو رابط اللعبة؛ ليس رابط GitHub.
9. انقر داخل اللعبة ثم Enter. جرّب الأسهم، الطعام، P، R، والرجوع إلى القائمة.

إذا طُلب منك Deploy command باستخدام `wrangler deploy` فأنت داخل مسار Workers؛
ارجع واختر Pages لمسار هذا الدليل.

## 3. تسليم الاساينمنت

- رابط GitHub يتيح للدكتور قراءة ملفات Lua الأصلية وتقسيمها.
- رابط Cloudflare يتيح تجربة اللعبة من المتصفح.
- أبقِ توضيح `<close>` وLua 5.4 الموجود في README مع المشروع: الويب لا يشغّل
  المسار الأصلي الخاص بـLua 5.4، بل مسار التوافق كما في LOVE العادي.

## 4. التعديلات القادمة

Cloudflare ينشر تلقائياً عند عمل commit جديد إلى `main`، لكن إعادة نشر ملفات
`web` القديمة لا تحوّل تعديلات Lua تلقائياً.

بعد أي تعديل على ملفات Lua:

1. ثبّت Node.js من https://nodejs.org إذا لم يكن موجوداً.
2. افتح Terminal داخل هذا المجلد وشغّل:

```sh
node scripts/build-web.mjs
```

3. ارفع ملفات Lua المعدّلة **وكل ناتج `web` الجديد** إلى GitHub.
4. راقب النشر الجديد في Cloudflare.

سكربت البناء يستخدم love.js من نسخة مصدر ثابتة للتكرار، ويجهّز ملف اللعبة
من ملفات Lua فقط، ثم ينسخ قالب صفحة التشغيل من `web-template` إلى `web`.
لا تعدّل `game.data` أو `love.wasm` يدوياً. لتعديل شكل صفحة الموقع عدّل ملفات
`web-template` وأعد البناء.

## أخطاء شائعة

| المشكلة | الحل |
| --- | --- |
| 404 عند فتح الموقع | تحقق من `web/index.html` وإعداد Build output directory = `web`. |
| يظهر طلب wrangler أو Deploy command | اختر Pages بدلاً من Workers. |
| لا يظهر المستودع في Cloudflare | راجع حساب GitHub المختار وصلاحية Cloudflare للمستودع. |
| اللعبة لا تستجيب للكيبورد | انقر داخل اللوحة واضغط Enter. |
| عدّلت Lua لكن اللعبة لم تتغير | أعد بناء نسخة الويب وارفع ناتج `web` الجديد. |
| لا يعمل فتح index.html بالنقر المزدوج | ملفات WebAssembly تحتاج تشغيل HTTP/HTTPS؛ استخدم رابط Cloudflare. |

اللعبة الحالية مصممة للكيبورد على الكمبيوتر؛ لم تتم إضافة أزرار لمس.

## التحقق الذي تم قبل التسليم

تم بناء نسخة compatibility من love.js بنجاح، وفحص بنية WebAssembly، وصحة
ملفات JavaScript ومراجع الملفات، وتشغيل فحوص منطق Lua. فحص المتصفح الفعلي
لهذه الحزمة غير متاح في بيئة التجهيز؛ اختبر رابط Cloudflare بعد أول نشر.

## المراجع الرسمية

- https://developers.cloudflare.com/pages/get-started/git-integration/
- https://developers.cloudflare.com/pages/framework-guides/deploy-anything/
- https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository
- https://github.com/Davidobot/love.js
