# Dosique — Privacy Policy

**Effective date:** [DATE]
**Contact:** [YOUR EMAIL]

Dosique ("the app") is a medication reminder and record-keeping app
developed for Android. This policy explains, in plain language, what
happens to your information when you use Dosique.

The short version: **Dosique collects nothing.** There is no account,
no sign-up, no analytics, no advertising, and no server. The developer
never receives your data — the app does not even request internet
access, so it has no way to send your data anywhere.

## 1. Data we collect

None. Dosique does not collect, transmit, sell, or share any personal
data or health data. No usage analytics, crash-reporting services, or
advertising SDKs are included in the app.

## 2. Data stored on your device

Everything you enter stays in the app's private storage on your own
device:

- Medicines (names, strengths, forms, instructions, notes, prescriber
  and pharmacy names you choose to type in)
- Schedules and reminder settings
- Dose history (taken, skipped, missed, as-needed logs)
- Stock quantities, refill and expiry information
- Profiles you create (for example, for family members or pets)
- Appointments
- Photos of medicines that you choose to attach
- Settings (theme, reminder tone, large-text mode, and similar)

This data never leaves your device unless **you** take an action that
sends it somewhere (see Section 3).

## 3. Sharing — only when you choose

Dosique has no sharing of its own. Data leaves your device only through
actions you start yourself:

- **Share today's schedule / missed-dose summary:** the app prepares a
  text summary and hands it to the app you pick (for example WhatsApp
  or SMS). What is sent, and to whom, is decided by you in that app.
- **Doctor report (PDF):** the app generates a PDF on your device and
  opens the system share sheet so you can send or save it where you
  like.
- **Backup export (JSON):** the app creates a backup file only when you
  tap Export, and you choose where it goes. Importing a backup is also
  started by you, using the system file picker.

Once you share something through another app or service, that app's own
privacy policy applies to the copy you sent.

## 4. Permissions, explained one by one

Dosique asks only for the permissions its features need:

- **Notifications (POST_NOTIFICATIONS):** to show dose reminders,
  refill reminders, and appointment reminders.
- **Exact alarms (SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM):** so dose
  reminders can ring at the exact time you set, like an alarm clock.
  These are used only for reminders you create.
- **Run at startup (RECEIVE_BOOT_COMPLETED):** so your reminders are
  restored automatically after the phone restarts.
- **Vibration (VIBRATE):** for the gentle vibration that can accompany
  a reminder and for haptic feedback on taps (can be turned off in
  Settings).
- **Photo picker:** only when you tap to attach a photo of a medicine.
  Dosique uses the Android system photo picker — you select the single
  photo, and the app receives access only to that image. It does not
  have access to your whole photo library. The photo is copied into the
  app's private storage on your device and is never uploaded anywhere.
- **Files (backup export/import):** Dosique does not request broad
  storage access. Export uses the system share sheet, and import uses
  the system file picker, so the app can only read the one backup file
  you select.

Dosique does **not** request internet access, location, contacts,
camera, microphone, or any health-sensor permissions.

## 5. Deleting your data

Your data is yours and it lives on your device:

- Delete individual medicines, profiles, appointments, or dose entries
  inside the app at any time.
- Delete **everything** by clearing the app's storage in Android
  Settings, or by uninstalling Dosique. Uninstalling removes all app
  data from the device.
- Because the developer never receives your data, there is no server
  copy to delete and no deletion request is needed. If you exported a
  backup file or shared a summary or PDF, deleting those copies is
  under your control in the place you saved or sent them.

## 6. Children

Dosique is a general-purpose reminder tool intended for adults managing
medication for themselves or their family. It is not directed at
children, it contains no advertising, and it collects no data from
anyone, including children. Profiles for family members are created and
managed by the device owner on their own device.

## 7. Medical disclaimer

Dosique is a reminder and recording tool only. It is **not** a medical
device, it does not provide medical advice, diagnosis, or treatment,
and it does not check drug interactions or dosage safety. Always follow
your prescriber's instructions and talk to your doctor or pharmacist
about your medicines.

## 8. Changes to this policy

If this policy changes, the updated version will be posted at the same
public URL with a new effective date, and the changes will be described
in the app's release notes.

## 9. Contact

Questions about this policy: [YOUR EMAIL]

---

**Note for the developer (remove before publishing):** replace
[YOUR EMAIL] with your real contact email and [DATE] with the
publication date, host this file at a public URL (for example GitHub
Pages, or a public page you control), and paste that URL into Play
Console under App content > Privacy policy. The in-project
PRIVACY_POLICY.md in the app source is a shorter draft of this text.
