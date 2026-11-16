# Shipping Aegyo to the App Store

Everything in the app runs on-device today. This is the list of what still has to happen outside the code,
in the order it makes sense to do it, plus the places in the project that change when you do.

## 1. Apple Developer Program (paid team)

The project currently builds with a free Personal Team, which cannot sign the entitlements the app needs.
Once you are enrolled:

- In Xcode, select the paid team for both targets (**Aegyo** and **AegyoWidgets**) under Signing & Capabilities,
  or set `DEVELOPMENT_TEAM` in `project.yml` and run `xcodegen generate`.
- Build with the real entitlements (`Aegyo/Aegyo.entitlements`), not `Config/Free.entitlements`.
- Register these capabilities for the `com.nabeelbukhari.aegyo` App ID in the developer portal:
  Push Notifications, App Groups (`group.com.nabeelbukhari.aegyo`), Sign in with Apple, Time Sensitive Notifications.
- Create an APNs key (`.p8`) for the backend. It is also needed for Live Activity push-to-start and the VoIP ring.

## 2. Backend

Two phones cannot exchange anything without a server. The app talks to the `Backend` protocol
(`Aegyo/Services/Backend/Backend.swift`); `LocalBackend` is the on-device implementation used today.
To go live, add a `FirebaseBackend` (or any other) that implements the same protocol and switch it in `Session`.
Everything else, from pairing to the Dynamic Island, is already built against that surface.

What the server must do:

| Call | Purpose |
|---|---|
| `signIn` / `deleteAccount` | Sign in with Apple or email, and full account deletion (App Store requirement 5.1.1(v)) |
| `createCouple` / `joinCouple` / `leaveCouple` | Pairing by 6-digit code and `aegyo://pair/CODE` link |
| `send` / `pullInbound` | Deliver each `LoveEvent` to the partner and push a Live Activity (APNs `liveactivity` push type) |
| `uploadPhoto` / voice note upload | Store media for photos and voice notes |
| `registerDeviceTokens` | APNs, Live Activity push-to-start and PushKit VoIP tokens |

## 3. App Store Connect

- Create the app record with bundle ID `com.nabeelbukhari.aegyo`, SKU of your choice, primary category Lifestyle.
- Age rating: 4+ (no objectionable content). Answer "No" to all content questions.
- **In-app purchases** (must match `Aegyo.storekit` exactly):

  | Product ID | Type | Price | Offer |
  |---|---|---|---|
  | `com.nabeelbukhari.aegyo.clingy.monthly` | Auto-renewable, group "Clingy" | $4.99 / month | 1-week free trial |
  | `com.nabeelbukhari.aegyo.clingy.annual` | Auto-renewable, group "Clingy" | $29.99 / year | 1-week free trial |
  | `com.nabeelbukhari.aegyo.clingy.lifetime` | Non-consumable | $59.99 | none |

  Attach the subscription group's localized display name "Clingy". Submit the products with the first build.
- Paid Apps agreement, tax and banking must be signed before purchases work in TestFlight.
- App Privacy questionnaire: declare **Name**, **Email**, **Photos or Videos**, **Audio Data**, **User Content**
  and **Coarse Location** (city) as collected, linked to the user, not used for tracking. Update
  `Aegyo/PrivacyInfo.xcprivacy` to list the same data types once the backend stores them.
- Host the privacy policy and terms at public URLs and put them in App Store Connect. The in-app text lives in
  `Aegyo/Features/Settings/SupportViews.swift` (`LegalView`); the support email is in the same file.

## 4. Build and submit

```bash
xcodegen generate
xcodebuild -project Aegyo.xcodeproj -scheme Aegyo -configuration Release -destination 'generic/platform=iOS' -archivePath build/Aegyo.xcarchive archive
```

Then Xcode › Organizer › Distribute App, or `xcodebuild -exportArchive` with an App Store export plist.
Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml` for each upload.

## 5. Review notes

Paste something like this into App Review Information:

> Aegyo is a private app for two partners. Create an account with Sign in with Apple or email, then pair with a
> second device using the 6-digit code shown on the Pairing screen (Settings › Pairing). A demo pairing can be
> reviewed on one device: the Dynamic Island, timeline, letters and voice notes preview on the sender's phone.
> Clingy is a subscription with a 1-week free trial; sandbox purchases work on the Paywall (Us tab › Clingy).
> Account deletion is in Settings › Account › Delete account.

Provide a demo account (email + password) if the backend requires one.

## 6. Screenshots and listing

- 6.9" (iPhone 17 Pro Max) and 6.5" screenshots are required. Capture from the simulator with the launch flags in
  `project.yml` (`-seedDemo -skipOnboarding -noTour -plus` plus `-openTimeline`, `-openPaywall`, etc.).
- Suggested set: Home with Doki, Dynamic Island, Action stack, Timeline, Sky, Paywall.
- App name "Aegyo", subtitle "Love, in your Dynamic Island", keywords around couples, long distance, widgets.

## 7. What is already done in the project

- Onboarding, sign-up, profile setup, permissions, pairing with every state, guided tour.
- Settings hub, profiles, reminders, sounds and haptics, appearance, privacy, help, feedback, about, legal,
  sign out, unpair, two-step account deletion that wipes all local data.
- StoreKit 2 store with local configuration, paywall, trial, restore, manage subscription, feature gating.
- Timeline, progress charts, achievements, calendar, saved, search, voice notes, edit and delete everywhere.
- Loading, empty, error and offline states; outbound queue that drains when back online.
- VoiceOver labels on every control, Dynamic Type up to XXXL (capped so the 3D layouts hold), Reduce Motion
  honoured from the system setting and from Settings › Appearance & motion.
- `PrivacyInfo.xcprivacy` for both targets, `ITSAppUsesNonExemptEncryption = NO`, lifestyle category,
  string catalog (`Aegyo/Localizable.xcstrings`) so the app is ready to translate.
- 1024-pt app icon, launch screen colour, portrait-only, iPhone only.

## 8. Known limits on the free team

Until the paid team is active, these cannot be verified on a real device: push and Live Activity push,
the App Group (photos inside the Dynamic Island), Sign in with Apple (the app falls back to email), and the
VoIP ring from a remote device. Builds signed with a Personal Team expire after 7 days.
