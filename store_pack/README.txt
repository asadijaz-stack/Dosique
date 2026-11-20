DOSIQUE — STORE PACK v1 (README)
====================================================================
Everything needed for the Google Play store listing of Dosique
(package com.dosique.app, version 1.0.0), in one folder.

FILES
--------------------------------------------------------------------
icon_512.png .............. Play store icon, 512x512. A faithful
                            resize of the app's ORIGINAL launcher
                            icon source (assets/icon/icon.png in the
                            app project, the flutter_launcher_icons
                            source) — not redesigned or redrawn, so
                            the store icon is identical to the icon
                            users see on their phone.
feature_graphic.png ....... 1024x500 store feature graphic: app icon
                            + "Dosique" + tagline "Never miss a dose
                            again." in the app's teal/emerald palette.
screenshots/ .............. 7 phone screenshots, 1080x1920 each:
                              01_today.png           Today screen
                              02_medicines.png       Medicines list
                              03_add_medicine.png    Add / schedules
                              04_reminder.png        Reminder moment
                              05_history.png         History calendar
                              06_stock_refills.png   Stock & refills
                              07_doctor_report.png   Report & sharing
listing.txt ............... Ready-to-paste store listing. Verified
                            character counts: title 22/30,
                            short description 73/80, full
                            description 2665/4000, What's New
                            485/500.
privacy_policy.md ......... Full publishable privacy policy. Replace
                            [YOUR EMAIL] and [DATE], host it at a
                            public URL, paste the URL into Play
                            Console.
data_safety.txt ........... Exact Data safety answers (collected:
                            NONE, shared: NONE) with the reasoning,
                            security-practices answers, the
                            permission-to-declaration mapping, and the
                            health-declaration guidance.
play_console_checklist.txt  Step-by-step console walkthrough for this
                            app, including the pre-publish jobs that
                            only you can do (email, policy hosting,
                            on-phone reminder test, key backup).

IMPORTANT — ABOUT THE SCREENSHOTS
--------------------------------------------------------------------
The 7 screenshots are MOCKUPS, drawn programmatically to match the
real app: same screens, same layout, same labels, same colours
(teal #0E9F8A on warm #FAF7F2, Material 3), and realistic sample data
(a profile called "Sarah" with Metformin, Vitamin D3, Omega-3,
Amoxicillin, Ibuprofen and Melatonin — the same data, times and
numbers across all 7 images). They are NOT photographs or captures
from a real phone. They are suitable to submit, but replacing them
with real captures from your own phone before publishing is the most
honest option and is recommended in the checklist.

ICON RULE — CONFIRMED
--------------------------------------------------------------------
icon_512.png was produced by directly resizing the app's original
icon source file (1024x1024) to 512x512. No new icon was designed.
The store icon therefore matches the in-app launcher icon exactly,
as required.

WHAT IS *NOT* IN THIS PACK
--------------------------------------------------------------------
- The AAB itself: build it on your PC with
  `flutter build appbundle --release` (see BUILD_ON_YOUR_PC.md in the
  app project). Signing key: dosique_release.jks, alias "dosique",
  android/app/key.properties — all on your PC only, never in a zip.
- Your contact email and the live privacy-policy URL: only you can
  supply those (marked [YOUR EMAIL] / [PRIVACY POLICY URL] in the
  files above).
