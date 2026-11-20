# ClipFlow Distribution Guide

## Current Status (Development)

✅ **בנייה מקומית עם חתימה**: האפליקציה נחתמת עם תעודת Apple Development  
⚠️ **הגבלה**: רק על המכשיר שלך - אחרים לא יכולים להתקין  
⚠️ **Accessibility**: צריך לתת הרשאה ידנית אחרי כל התקנה

---

## דרכי הפצה

### 1. 🔧 **Development (עכשיו)**

**מה שיש:**
- חתימה עם Apple Development certificate
- עובד רק על המחשב שלך
- Accessibility צריך הרשאה ידנית

**איך להתקין:**
```bash
./build-app.sh              # בניה
./install-app.sh            # התקנה
./check-app.sh              # בדיקת סטטוס
```

**Debug:**
```bash
# לוגים בזמן אמת
log stream --predicate 'process == "ClipFlow"' --level debug

# איפוס הרשאת Accessibility
tccutil reset Accessibility io.benesh.clipflow

# בדיקת חתימה
codesign -dv /Applications/ClipFlow.app
```

---

### 2. 📱 **TestFlight (Beta Testing)**

**עלות:** $99/שנה (Apple Developer Program)  
**יתרונות:**
- עד 10,000 בודקים
- Accessibility עובד אוטומטית
- עדכונים אוטומטיים
- קבלת feedback מבודקים

**תהליך:**
1. הרשמה ל-Apple Developer Program
2. יצירת App ID ב-App Store Connect
3. הגדרת TestFlight
4. בניה עם `xcodebuild` + העלאה עם `xcrun altool`
5. שליחת הזמנות לבודקים

**זמן:** ~2-3 ימי עבודה להקמה ראשונית

---

### 3. 🌐 **App Store (Production)**

**עלות:** $99/שנה + 30% עמלה על מכירות  
**יתרונות:**
- הפצה פומבית לכולם
- עדכונים אוטומטיים
- Accessibility + כל ההרשאות עובדות
- אמינות מקסימלית

**דרישות נוספות:**
- Privacy Policy
- App Screenshots + Description
- App Review (7-10 ימים)
- עמידה ב-App Store Guidelines

**זמן:** ~2-3 שבועות עד אישור ראשון

---

### 4. 🔓 **GitHub Releases + Notarization (Open Source)**

**עלות:** $99/שנה (רק Developer Program)  
**יתרונות:**
- הפצה חופשית ללא עמלות
- Accessibility עובד לאחרים
- אין App Review
- שליטה מלאה

**תהליך:**
1. חתימה עם Developer ID certificate (לא Development!)
2. Notarization דרך Apple
3. העלאה ל-GitHub Releases
4. משתמשים מורידים DMG/ZIP

**זמן:** ~1 יום להקמה

**קוד לדוגמה:**
```bash
# 1. חתימה עם Developer ID
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp --options runtime \
    --entitlements ClipFlow.entitlements \
    ClipFlow.app

# 2. יצירת DMG
hdiutil create -volname "ClipFlow" -srcfolder ClipFlow.app \
    -ov -format UDZO ClipFlow.dmg

# 3. Notarization
xcrun notarytool submit ClipFlow.dmg \
    --apple-id your@email.com \
    --team-id TEAM_ID \
    --password app-specific-password

# 4. Staple (לאחר אישור)
xcrun stapler staple ClipFlow.dmg
```

---

## המלצה שלי

### לפיתוח (עכשיו):
✅ **המשך עם Development signing** - עובד מצוין למה שאתה צריך

### לבדיקות Beta:
🥇 **TestFlight** - הכי פשוט להזמין בודקים, Accessibility עובד

### לשחרור סופי:
🥇 **GitHub Releases + Notarization** - מושלם לפרויקט open source
- אפס עמלות
- שליטה מלאה
- עובד כמו צריך
- דוגמאות: Maccy, Rectangle, Stats

אלטרנטיבה: **App Store** אם רוצה לגבות כסף או הפצה רחבה יותר

---

## Next Steps (אם תרצה להמשיך)

### עכשיו (חינם):
1. ✅ Development signing (סיימנו!)
2. בדיקת UI/UX על המכשיר שלך
3. תיקון באגים

### בעתיד ($99/שנה):
1. רכישת Apple Developer Program
2. יצירת Developer ID certificate
3. Notarization setup
4. GitHub Releases automation
5. אופציונלי: TestFlight לבטא

---

## Scripts זמינים

```bash
./build-app.sh      # Build + Sign
./install-app.sh    # Install to /Applications
./check-app.sh      # Check status, version, signing
```

## Troubleshooting

### "Accessibility permission resets"
זה תקין בפיתוח. כל build חדש = הרשאה חדשה.  
פתרון: Notarization (דורש Developer Program)

### "App crashes on launch"
```bash
# Check crash logs
log show --predicate 'process == "ClipFlow"' --last 5m
```

### "Icons/Resources missing"
```bash
ls -la /Applications/ClipFlow.app/Contents/Resources/
```

---

**Bottom Line:**  
הכל עובד עכשיו למעשה. אם תרצה להפיץ לאחרים - $99/שנה ויום אחד עבודה להגדיר Notarization.
