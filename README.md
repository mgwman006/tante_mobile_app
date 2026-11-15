# Tante mobile app

## Run locally

Local API URLs default to `localhost` and the backend development ports:

| Service | Local URL |
| --- | --- |
| Auth manager | `http://localhost:8081/auth-manager` |
| Property manager | `http://localhost:8082/property-manager` |
| Rent manager | `http://localhost:8083/rent-manager` |

Start the backend services, then run the app on the iPhone simulator:

```sh
flutter run -d "iPhone 17" --dart-define-from-file=config/local.json
```

`config/local.json` is optional when using these default URLs. On a physical
phone, replace `localhost` with the development machine's LAN IP address.

## Run or build with production APIs

```sh
flutter run -d "iPhone 17" --dart-define-from-file=config/production.json
flutter build ipa --dart-define-from-file=config/production.json
```

Flutter reads these values at compile time. To use another environment, pass
`--dart-define=AUTH_API_BASE_URL=...`, `--dart-define=PROPERTY_API_BASE_URL=...`,
and `--dart-define=RENT_API_BASE_URL=...`, or use a JSON file with
`--dart-define-from-file`.

Do not put credentials or other secrets in dart defines; they are embedded in
the application binary.
