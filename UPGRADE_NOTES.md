# Economofar (iPhone app) - upgrade notes

Installed by `economofar_upgrade.py`. Every file that was changed has a copy in `.upgrade-backup/`
(this folder). To go back: run `python3 economofar_upgrade.py --undo` from the Projects folder.

## 2 small settings to add in Xcode (20 seconds)

Select the app target > **Info** tab > add these rows:

1. **Privacy - Face ID Usage Description**  =  `Economofar utilise Face ID pour verrouiller l'application.`
   (without it the lock falls back to the device passcode only)
2. Only if you test on a real iPhone over http: **App Transport Security Settings** >
   **Allows Local Networking** = `YES`
   (the default server `http://localhost:8080` works in the Simulator without it)

If your project has a real `Info.plist` file, the installer already added these keys for you.

## What is new

- **Server address** (Settings > Assistance > "Adresse du serveur"): no more hard-coded `localhost`.
  On a real iPhone type your Mac's address, for example `http://192.168.1.20:8080`.
  `Core/Config/AppConfig.swift` is the single place that knows the server address.
- **Safer login**: the JWT is stored in the iOS Keychain (the old UserDefaults value is migrated automatically).
  When the server answers 401 the app returns to the login screen by itself.
- **Face ID / passcode lock** (Settings > Sécurité): locks the app when it goes to the background.
- **Analytics tab** (`Features/Analytics`): spending per month, per category, top merchants, payment methods.
- **Scan flow fixed**: the photo and the ticket created at upload are kept and finalized when you press
  Save (no more duplicate tickets, no more lost photo). Cancel removes the unfinished ticket.
  The validation sheet now has a date picker and a payment method picker, and shows save errors.
- **Delete my account** (Settings > Compte et donnees).
- Clear error messages on login / registration (wrong password, e-mail already used, too many attempts).

## Not done yet (good next steps)

- Apply the currency / language chosen in the profile to every screen (`AppFormat` is ready for it).
- Several empty placeholder files (`Core/Components`, `Core/DesignSystem`, `Services/Receipt/OCRService.swift`, ...)
  are still empty; nothing uses them today, so they can be filled or deleted later.
