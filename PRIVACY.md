# سياسة الخصوصية: دربك

**آخر تحديث:** ٢٦ نوفمبر ٢٠٢٦

دربك تطبيق عداد خطوات من تطوير **0xF8D**. هذي الصفحة توضح وش البيانات اللي يستخدمها التطبيق، ووين تنحفظ، ومين يشوفها.

## ١. البيانات اللي تبقى في جوالك
هذي ما تطلع من جوالك أبداً:
- **من تطبيق «صحتي» (HealthKit):** الخطوات، والمسافة، والسعرات النشطة، والطوابق. التطبيق **يقرأ** بس، وما يكتب ولا يعدل شي في «صحتي».
- **من عداد الجوال (Motion & Fitness):** الخطوات، عشان الرقم يتحدث وأنت تمشي.
- **اللي تسجله بنفسك:** المويه، والأكل والطبخات، والأهداف والإعدادات.
- **ملف التصدير من «صحتي»** (لو استوردته): التطبيق يقرأ منه مجاميع الخطوات اليومية بس، ويحفظها في الجوال.

## ٢. البيانات اللي تنرسل لسيرفر الشلة (لو دخلت مجموعة بس)
لو وافقت ودخلت مجموعة أو أنشأت وحدة، التطبيق يرسل:
- **اسمك ورمزك** اللي تختارهم أنت.
- **مستواك** في التطبيق.
- **مجموع خطواتك لكل يوم** في الأسبوع الحالي. **رقم واحد لكل يوم بس**، بدون أي تفاصيل ثانية من «صحتي».
- **رقم نسخة التطبيق.**
- **معرّف عشوائي** يتسوى في جوالك، و**بصمة مشفرة** من رمز سري. الرمز نفسه ما يطلع من جوالك.

**مين يشوفها؟** أعضاء المجموعات اللي أنت فيها بس. والمطور يقدر يشوف الإحصائيات العامة (عدد المستخدمين، والنسخ، والمجموعات) عشان يدير الخدمة ويمنع الإساءة.

**وين تنحفظ؟** في قاعدة بيانات على **Supabase**، وهي خدمة استضافة سحابية.

## ٣. اللي ما نجمعه أبداً
- ما فيه **تسجيل دخول**، ولا **إيميل**، ولا **رقم جوال**.
- ما نرسل **موقعك**. «وضع المشي» يستخدم الموقع بس عشان يبقى التطبيق شغال بالخلفية، وما يحفظه ولا يرسله.
- ما فيه **إعلانات**، ولا **تتبع**، ولا **بيع بيانات**، ولا مشاركتها مع أي طرف ثالث.
- بيانات «صحتي» **ما تُستخدم للإعلانات** ولا تنحفظ في iCloud.

## ٤. حذف بياناتك
- **من التطبيق:** الإعدادات ← «حسابك في الشلة» ← **«احذف حسابي وبياناتي»**. ينحذف كل شي عنك من السيرفر على طول، وتطلع من كل المجموعات، والمجموعات اللي أنت صاحبها تنحذف.
- **البيانات اللي في جوالك:** تنحذف لما تحذف التطبيق.
- **الطلع من مجموعة:** من صفحة الشلة ← «اطلع من المجموعة».

## ٥. الأطفال
التطبيق مو موجه للأطفال تحت ١٣ سنة، وما نجمع بياناتهم عن قصد.

## ٦. التواصل
لأي سؤال عن الخصوصية: https://github.com/0xF8D/Darbak/issues

---

# Privacy Policy: Darbak

**Last updated:** November 26, 2026

Darbak is a step counter developed by **0xF8D**.

**Stays on your device:** steps, distance, active energy and flights read from Apple Health (read-only), phone pedometer data, water and food logs, goals and settings, and step totals imported from a Health export.

**Sent to the groups server, only if you consent and join a group:** your chosen name and emoji, your level, one step total per day for the current week, the app version, and a random device ID with a hashed secret. Members of your groups see this data; the developer can see aggregate stats to run the service. Data is hosted on Supabase.

**Never collected:** no login, email or phone number; no location is sent (Walk Mode uses location only to keep the app running); no ads, tracking, data selling or third-party sharing. Health data is never used for advertising or stored in iCloud.

**Deleting your data:** Settings → "حسابك في الشلة" → "احذف حسابي وبياناتي" deletes everything about you from the server immediately. On-device data is removed when you delete the app.

**Children:** not directed to children under 13.

**Contact:** https://github.com/0xF8D/Darbak/issues
