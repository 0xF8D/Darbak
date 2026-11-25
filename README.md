<div align="center">

<img src="icon.png" width="120" alt="دربك">

# دربك · Darbak

**عداد خطوات: مستويات وتحديات وتنافس مع شلتك**

المطور: **0xF8D** · 🇸🇦 **Saudi Made**

[![Download](https://img.shields.io/badge/Download-Darbak.ipa-22E1FF?style=for-the-badge)](https://github.com/0xF8D/steps/releases/download/latest/Darbak.ipa)

iOS 16.2 وفوق · آيفون وآيباد

</div>

---

## وش يسوي دربك؟

دربك يقرأ خطواتك من **«صحتي»** (الجوال والساعة) ويعرضها لك بحلقة تتحدث وأنت تمشي، ويحمّسك بالمستويات والتحديات والمنافسة مع شلتك.

## المميزات

| | |
|---|---|
| 👟 **خطوات مباشرة** | أرقامك نفس اللي في «صحتي»، وتتحدث كل ثانيتين وأنت تمشي |
| ⭐ **المستويات** | تجمع نقاط (XP) من خطواتك وتطلع من «مبتدئ» لين «أسطورة» |
| 🏁 **التحديات** | ٣ تحديات كل أسبوع و٣ كل شهر، أرقامها تتغير حسب معدلك |
| 💎 **الدروع** | درع لكل يوم توصل فيه ٧ أو ٨ أو ٩ أو ١٠ آلاف خطوة |
| 👥 **الشلة** | نافس شلتك على خطوات الأسبوع، والأول «ملك القروب 👑» |
| 🔔 **التذكير** | «باقيلك ١٬٢٣٤ خطوة على هدفك يا وحش 💪» |
| 📱 **ويدجت** | للشاشة الرئيسية وشاشة القفل، ووضع المشي على الجزيرة |
| 🍽️ **السعرات** | حاسبة سعرات، مكوناتك، طبخاتك، وسجل يومك |

## كيف تجمع XP؟

| | النقاط |
|---|---|
| كل ١٠٠ خطوة | +١ |
| كل درع تجيبه باليوم | +٢٥ |
| تحدي أسبوعي | +١٥٠ |
| تحدي شهري | +٤٠٠ |

مستواك يتحسب من سجلك كامل، فأيامك القديمة تنحسب لك.

## الشلة: كيف تشتغل؟

1. افتح تبويب **الشلة** واكتب اسمك واختار رمزك.
2. اضغط **«أرسل كودي للقروب»** وأرسله لشلتك.
3. لما يرسل صديقك كوده: انسخ رسالته، وارجع للتطبيق واضغط **«لصق»**.

> ما فيه سيرفر ولا حسابات. الترتيب يتحدث كل ما أحد يرسل كود جديد، فأرسلوا أكوادكم كل يوم أو آخر الأسبوع.

## التثبيت

1. حمّل الملف: [Darbak.ipa](https://github.com/0xF8D/steps/releases/download/latest/Darbak.ipa)
2. ثبّته بأي برنامج تثبيت (مثل AltStore أو Sideloadly أو غيرها).
3. افتح دربك واسمح له يقرأ من **«صحتي»**.

**مصدر AltStore** (عشان توصلك التحديثات):

```
https://raw.githubusercontent.com/0xF8D/steps/main/apps.json
```

> بعض برامج التوقيع تشيل صلاحية «صحتي» أو App Groups. لو انشالت الصحة يشتغل التطبيق على عداد الجوال (آخر ٧ أيام بس)، ولو انشال App Group يطلع الويدجت فاضي.

## الخصوصية

كل بياناتك تبقى في جوالك. دربك ما عنده سيرفر وما يرسل أي شي لأي مكان. الشي الوحيد اللي يطلع من جوالك هو الكود اللي ترسله أنت بنفسك لشلتك (اسمك ورمزك وخطوات أسبوعك ومستواك).

## للمطورين: البناء بدون ماك

المشروع مكتوب بـ SwiftUI ويتبني على GitHub Actions:

1. أي push على `main` (أو **Actions ← Build IPA ← Run workflow**).
2. بعد دقايق ينزل `Darbak.ipa` في **Releases ← latest**.

الملفات:
- `Sources/`: التطبيق
- `Widget/`: الويدجت ووضع المشي
- `Shared/`: كود مشترك بين التطبيق والويدجت
- `project.yml`: إعداد XcodeGen

---

## English

**Darbak** is a step counter for iPhone & iPad (iOS 16.2+): levels, challenges, and competing with your friends.

- 👟 **Live steps** that match Apple Health (iPhone + Apple Watch)
- ⭐ **XP levels**: earn points from your steps, from *Beginner* to *Legend*
- 🏁 **Challenges**: 3 weekly + 3 monthly, adapted to your average
- 👥 **Friends**: weekly leaderboard by sharing a code, no server, no account
- 📱 **Widgets**, Live Activity, reminders, and a calorie tracker

**Install:** download [Darbak.ipa](https://github.com/0xF8D/steps/releases/download/latest/Darbak.ipa) and sideload it (AltStore, Sideloadly, …).
**Privacy:** everything stays on your device.
**Build:** SwiftUI + XcodeGen, built by GitHub Actions on every push to `main`.

Made by **0xF8D** · 🇸🇦 Saudi Made

---

<div align="center">

© 2026 0xF8D · جميع الحقوق محفوظة · 🇸🇦 Saudi Made

</div>
