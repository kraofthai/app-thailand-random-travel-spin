# TeawNaiD

Flutter app for random travel discovery around Thailand.

## Production Build

Firebase is enabled by default. Build Android App Bundle for Google Play:

```bash
flutter build appbundle --release
```

Build with the Render backend URL:

```bash
flutter build appbundle --release --dart-define=PLACES_API_BASE_URL=https://teawnaid-tat-proxy.onrender.com
```

Do not put the TAT API key directly in the mobile app. The app expects a backend
proxy that exposes `/api/places/all`, `/places`, and `/api/image`.

## Render Backend With Firestore Cache

The Node backend can sync TAT places into Firestore, then serve app requests from
our own `places` collection instead of calling TAT for every user request.

### Render Environment Variables

Set these in Render. Do not commit real values to GitHub.

- `TAT_API_KEY`
- `TAT_API_BASE_URL=https://tatdataapi.io`
- `TAT_API_AUTH_HEADER=x-api-key`
- `TAT_API_PLACES_PATH=/api/v2/places`
- `TAT_API_PLACE_DETAIL_PATH=/api/v2/places/{id}`
- `TAT_API_DEFAULT_LIMIT=20`
- `TAT_API_LOCALE=en`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `ADMIN_SYNC_TOKEN`

### Firebase Service Account

Create a service account key in Firebase/Google Cloud:

1. Open Firebase Console > Project settings > Service accounts.
2. Generate a new private key.
3. Copy these fields from the JSON into Render Environment:
   - `project_id` -> `FIREBASE_PROJECT_ID`
   - `client_email` -> `FIREBASE_CLIENT_EMAIL`
   - `private_key` -> `FIREBASE_PRIVATE_KEY`
4. Paste the private key exactly. If Render stores it as one line, keep the
   escaped `\n` characters; the server converts them at runtime.

### Sync TAT Places

After deployment and env setup:

```bash
curl -X POST \
  -H "x-admin-token: YOUR_ADMIN_SYNC_TOKEN" \
  "https://teawnaid-tat-proxy.onrender.com/admin/sync-places"
```

Optional smaller/larger TAT page size:

```bash
curl -X POST \
  -H "x-admin-token: YOUR_ADMIN_SYNC_TOKEN" \
  "https://teawnaid-tat-proxy.onrender.com/admin/sync-places?pageSize=100"
```

### Public API

```bash
curl "https://teawnaid-tat-proxy.onrender.com/health"
curl "https://teawnaid-tat-proxy.onrender.com/places?limit=20"
curl "https://teawnaid-tat-proxy.onrender.com/places?province=เชียงใหม่&limit=20"
curl "https://teawnaid-tat-proxy.onrender.com/places?categoryFilter=nature&limit=20"
curl "https://teawnaid-tat-proxy.onrender.com/places/random"
curl "https://teawnaid-tat-proxy.onrender.com/places/random?region=ภาคเหนือ"
curl "https://teawnaid-tat-proxy.onrender.com/places/6513"
```

The existing Flutter endpoint `/api/places/all` remains available. It reads from
Firestore first and falls back to TAT only when the cache is empty or refreshed.
The app loads a small `/places?limit=120` preview for the opening animation, then
uses `/places/random` so the real random result comes from the full Firestore
cache.

### Google Sign-In for Play Testing

For Google Play internal testing, add the Play App Signing SHA certificates to
Firebase. Open Play Console > App integrity > App signing key certificate, copy
SHA-1 and SHA-256, then add them to the Firebase Android app
`com.teawnaid.app`. Download the updated `google-services.json`, rebuild the
AAB, and upload a new test release.

## TAT Live API Backend

The Firebase HTTPS function `travelApi` proxies TAT API requests without exposing
the TAT key inside the mobile app.

After Firebase CLI re-authentication, set the secret and deploy:

```bash
awk -F= '/^TAT_API_KEY=/{print substr($0,index($0,"=")+1)}' .env | firebase functions:secrets:set TAT_API_KEY --data-file=- --project random-travel-27cc6 --force
firebase deploy --project random-travel-27cc6 --only functions:travelApi
```

Firebase Cloud Functions requires the Blaze plan for Secret Manager and HTTPS
functions. If you want a free first release, deploy `server.mjs` as a Render web
service using `render.yaml`, set `TAT_API_KEY` in Render Environment, then build:

```bash
flutter build appbundle --release --dart-define=PLACES_API_BASE_URL=https://your-render-service.onrender.com
```

Release signing files are intentionally not committed:

- `android/key.properties`
- `android/app/teawnaid-upload-key.jks`

Back them up securely before uploading to Google Play.
