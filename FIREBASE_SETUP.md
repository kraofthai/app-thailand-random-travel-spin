# TeawNaiD Firebase Setup

แอพรองรับ Phase 1 login แบบเบา ๆ แล้ว:

- เปิดแอพและสุ่มที่เที่ยวได้โดยไม่ต้อง login
- ฟีเจอร์แต้ม, bonus spin, leaderboard, redeem และ check-in จะขอ login ก่อน
- ถ้ายังเชื่อม Firebase ไม่ได้ แอพจะใช้ Guest/local fallback เพื่อให้ใช้งานพื้นฐานได้

## สถานะตอนนี้

เชื่อม Firebase project `random-travel-27cc6` แล้วด้วย FlutterFire CLI:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- Android Gradle Google Services plugin
- Android package จริง: `com.teawnaid.app`
- Android debug และ upload-key SHA-1/SHA-256 เพิ่มใน Firebase แล้ว
- iOS Sign in with Apple entitlement เพิ่มใน Xcode project แล้ว
- `firebase.json`
- Firestore rules/indexes deploy แล้ว
- Storage rules deploy แล้ว
- Beta Points เปิดใช้ผ่าน Firestore transaction ชั่วคราวระหว่างรอ Blaze plan

Firebase App IDs ที่สร้างแล้ว:

- Web: `1:155085357502:web:7b8ae3cea82cec369cb9ef`
- Android: `1:155085357502:android:c80a53073352e6f19cb9ef`
- iOS: `1:155085357502:ios:b0f37cc98de87f3a9cb9ef`

## เปิด Firebase จริง

Firebase เปิดเป็นค่าเริ่มต้นแล้ว ถ้าต้องปิดชั่วคราวตอนทดสอบ local ค่อยใส่:

```bash
flutter run --dart-define=FIREBASE_ENABLED=false
```

ถ้าต้อง reconfigure:

```bash
flutterfire configure --project=random-travel-27cc6
```

ใน Firebase Console เปิดแล้ว:

- Authentication providers: Google, Apple

ใน Firebase Console ยังควรเปิดบริการ:

- Analytics

## สิ่งที่ต้องเปิดใน Console

Authentication providers เปิดจาก Firebase Console แล้ว:

- Google
- Apple สำหรับ iOS

Cloud Functions ยัง deploy ไม่ได้จนกว่า project จะเป็น Blaze plan:

```text
Required API artifactregistry.googleapis.com can't be enabled until the upgrade is complete.
```

หลังอัปเกรด Blaze แล้ว deploy function แต้มด้วย:

```bash
firebase deploy --project random-travel-27cc6 --only functions:awardPointTransaction
```

ระหว่างรอ Blaze แอพจะใช้ Beta Points ผ่าน Firestore transaction:

- ใช้ได้เฉพาะ user ที่ login แล้ว
- จำกัดประเภท event และจำนวนแต้มตาม rules
- เหมาะสำหรับ Phase 1 / beta / ทดสอบ leaderboard
- ยังไม่ควรใช้แลกรางวัลจริงหรือผูกกับ partner จนกว่าจะย้ายไป Cloud Functions

## ก่อนปล่อย Google Play จริง

- หลังอัปโหลด AAB และเปิด Play App Signing แล้ว ให้คัดลอก SHA-1/SHA-256 ของ **App signing key certificate** จาก Play Console มาเพิ่มใน Firebase Android app `com.teawnaid.app`
- ใช้ TAT live API ผ่าน Firebase HTTPS Function:
  `--dart-define=PLACES_API_BASE_URL=https://asia-east2-random-travel-27cc6.cloudfunctions.net/travelApi`
- ถ้ายังไม่มี backend proxy แอพจะใช้ข้อมูลสำรองในตัวแอพแทน และไม่ฝังคีย์ TAT ไว้ในแอพโดยตรง

## TAT Live API

เพิ่ม Firebase HTTPS Function `travelApi` แล้ว โดย endpoint หลักคือ:

```text
https://asia-east2-random-travel-27cc6.cloudfunctions.net/travelApi
```

หลัง re-auth Firebase CLI ให้ตั้ง secret และ deploy:

```bash
awk -F= '/^TAT_API_KEY=/{print substr($0,index($0,"=")+1)}' .env | firebase functions:secrets:set TAT_API_KEY --data-file=- --project random-travel-27cc6 --force
firebase deploy --project random-travel-27cc6 --only functions:travelApi
```

ถ้า deploy ติด billing ต้องเปิด Blaze plan ก่อน เพราะ HTTPS Cloud Functions ต้องใช้ Cloud Functions runtime จริง.

## Firestore Collections

`users`

- `uid`
- `displayName`
- `photoUrl`
- `points`
- `totalSpin`
- `level`
- `createdAt`
- `lastLogin`

`point_transactions`

- `userId`
- `type`
- `points`
- `description`
- `createdAt`

`leaderboard`

- `userId`
- `displayName`
- `points`
- `rank`
- `month`

`rewards`

- `rewardName`
- `partnerName`
- `pointCost`
- `couponCode`
- `expiredAt`
- `status`

## Point Rules In App

- เปิดแอพรายวัน: +5
- กดสุ่มทริป: +2
- บันทึกสถานที่: +3
- Check-in พร้อมรูป/รีวิว: +30
- แลก spin: 100 points = 1 spin

## Cloud Functions

แอพจะเรียก callable function ชื่อ `awardPointTransaction` ก่อน เพื่อให้คำนวณแต้มฝั่ง server และกันการโกงจาก client.

ตอนนี้ function ยัง deploy ไม่ได้จนกว่า Firebase project จะอัปเกรดเป็น Blaze plan. ระหว่างนี้ login, Storage, Firestore rules ใช้ได้ และแอพจะ fallback เป็น Beta Points ผ่าน Firestore transaction.
