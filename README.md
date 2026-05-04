# TeawNaiD

Flutter app for random travel discovery around Thailand.

## Production Build

Firebase is enabled by default. Build Android App Bundle for Google Play:

```bash
flutter build appbundle --release
```

If the TAT proxy backend has been deployed, pass its public HTTPS URL:

```bash
flutter build appbundle --release --dart-define=PLACES_API_BASE_URL=https://asia-east2-random-travel-27cc6.cloudfunctions.net/travelApi
```

Do not put the TAT API key directly in the mobile app. The app expects a backend
proxy that exposes `/api/places/all` and `/api/image`.

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
