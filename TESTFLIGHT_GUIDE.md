# TestFlight Deployment Guide for Penguin Sensei

This guide walks you through deploying your iOS app to TestFlight for the first time.

---

## Prerequisites

Before starting, make sure you have:
- [ ] An Apple Developer account ($99/year) - https://developer.apple.com/programs/
- [ ] Xcode installed (latest version recommended)
- [ ] Your Apple ID signed in to Xcode

---

## Part 1: Apple Developer Portal Setup

### Step 1: Create an App ID

1. Go to https://developer.apple.com/account
2. Sign in with your Apple ID
3. Click **"Certificates, Identifiers & Profiles"** in the left sidebar
4. Click **"Identifiers"** in the left menu
5. Click the **"+"** button (top left, next to "Identifiers")
6. Select **"App IDs"** and click **Continue**
7. Select **"App"** (not App Clip) and click **Continue**
8. Fill in:
   - **Description**: `Penguin Sensei`
   - **Bundle ID**: Choose "Explicit" and enter: `com.yourname.penguinsensei`
     - Replace `yourname` with something unique to you
     - Example: `com.marioscian.penguinsensei`
9. Scroll down to **Capabilities** and check:
   - [x] **Sign In with Apple** ← IMPORTANT!
10. Click **Continue**, then **Register**

### Step 2: Create a Provisioning Profile (Xcode usually handles this automatically)

Xcode typically manages this for you. If you run into signing issues:

1. In Developer Portal, go to **"Profiles"**
2. Click **"+"** to create new profile
3. Select **"iOS App Development"** for testing
4. Select your App ID (Penguin Sensei)
5. Select your development certificate
6. Select your test devices
7. Name it "Penguin Sensei Development"
8. Download and double-click to install

---

## Part 2: App Store Connect Setup

### Step 1: Create Your App

1. Go to https://appstoreconnect.apple.com
2. Sign in with your Apple ID
3. Click **"My Apps"** (or the "+" if you have other apps)
4. Click the **"+"** button → **"New App"**
5. Fill in the form:

| Field | Value |
|-------|-------|
| **Platforms** | ✓ iOS |
| **Name** | `Penguin Sensei` |
| **Primary Language** | English (U.S.) |
| **Bundle ID** | Select the one you created (com.yourname.penguinsensei) |
| **SKU** | `penguinsensei001` (any unique identifier) |
| **User Access** | Full Access |

6. Click **"Create"**

### Step 2: App Information (Optional for TestFlight, Required for App Store)

After creating the app, you'll see the app page. For TestFlight only, you can skip most of this. But fill in:

1. Click **"App Information"** in the left sidebar
2. Set **Category**: Education
3. Set **Content Rights**: Check "This app does not contain..."
4. Click **Save**

---

## Part 3: Configure Xcode Project

### Step 1: Open the Project

1. Open Finder and navigate to:
   ```
   /Users/mario/Personal/AI Apps/kanji-memory-ios/
   ```
2. Double-click **`KanjiMemory.xcodeproj`** to open in Xcode

### Step 2: Update Bundle Identifier

1. In Xcode, click on **"KanjiMemory"** in the left sidebar (the project, blue icon)
2. Select **"KanjiMemory"** under TARGETS
3. Go to the **"Signing & Capabilities"** tab
4. Under **"Bundle Identifier"**, change it to match what you created:
   ```
   com.yourname.penguinsensei
   ```
   (Use the EXACT same bundle ID from Step 1 of Developer Portal)

### Step 3: Set Up Signing

1. Still in **"Signing & Capabilities"** tab:
2. Check **"Automatically manage signing"**
3. Select your **Team** from the dropdown
   - If you don't see your team, go to Xcode → Settings → Accounts → Add your Apple ID
4. Xcode should show a green checkmark ✓ if signing is configured correctly

### Step 4: Verify Sign In with Apple Capability

1. Still in **"Signing & Capabilities"** tab
2. You should see **"Sign In with Apple"** listed
3. If not, click **"+ Capability"** and add it

### Step 5: Set Version and Build Numbers

1. Still in the **General** tab (next to Signing & Capabilities)
2. Set:
   - **Version**: `1.0.0`
   - **Build**: `1`

### Step 6: Select Destination

1. In the top toolbar, next to the Play/Stop buttons
2. Click on the device selector (might say "iPhone 15 Pro")
3. Select **"Any iOS Device (arm64)"**
   - This is required for archiving

---

## Part 4: Archive and Upload

### Step 1: Create Archive

1. In Xcode menu bar: **Product → Archive**
2. Wait for the build to complete (may take 2-5 minutes)
3. When done, the **Organizer** window will open automatically

### Step 2: Validate the Archive

1. In the Organizer window, select your archive
2. Click **"Validate App"** button (right side)
3. Select your distribution method: **"App Store Connect"**
4. Click **Next**
5. Select **"Upload"** (to send to App Store Connect)
6. Click **Next**
7. Keep defaults checked, click **Next**
8. Select your signing certificate (should auto-select)
9. Click **Validate**
10. Wait for validation... should show ✓ green checkmark

### Step 3: Upload to App Store Connect

1. Still in Organizer, click **"Distribute App"**
2. Select **"App Store Connect"** → **Next**
3. Select **"Upload"** → **Next**
4. Keep defaults → **Next**
5. Confirm signing → **Upload**
6. Wait for upload... (may take 5-10 minutes depending on internet)
7. You'll see "Upload Successful" when done!

---

## Part 5: Set Up TestFlight

### Step 1: Wait for Processing

1. Go to https://appstoreconnect.apple.com
2. Click **"My Apps"** → **"Penguin Sensei"**
3. Click **"TestFlight"** tab at the top
4. You'll see your build listed with status **"Processing"**
5. Wait 10-30 minutes for Apple to process the build
6. You'll get an email when it's ready

### Step 2: Add Test Information (Required)

Once processing is complete:

1. Click on your build number (e.g., "1")
2. You'll see **"Missing Compliance"** warning
3. Click **"Manage"** next to Export Compliance
4. Answer the question:
   - "Does your app use encryption?" → **No**
   - (Our app uses HTTPS which is exempt)
5. Click **Save**

### Step 3: Add Internal Testers (Your Personal Testing)

1. In TestFlight tab, click **"Internal Testing"** in sidebar
2. Click **"+"** next to "Internal Testing"
3. Create a new group: "Personal Testing"
4. Click **"Create"**
5. Click **"+"** next to "Testers"
6. Add your Apple ID email
7. Click **"Add"**

### Step 4: Add Builds to Test Group

1. Click on your test group "Personal Testing"
2. Click **"Builds"** tab
3. Click **"+"** to add a build
4. Select your build and click **"Add"**

### Step 5: Install on Your Device

1. On your iPhone, download **"TestFlight"** app from App Store
2. Open TestFlight
3. You should see "Penguin Sensei" listed
4. Tap **"Install"**
5. The app will install on your home screen!

---

## Troubleshooting

### "No signing certificate found"
1. Go to Xcode → Settings → Accounts
2. Select your Apple ID → Manage Certificates
3. Click "+" → Apple Development
4. This creates a new certificate

### "Bundle ID already in use"
- Someone else registered that bundle ID
- Choose a different one (add your name/company)

### Build fails with SwiftData errors
- Make sure Deployment Target is iOS 17.0 or higher
- Clean build folder: Product → Clean Build Folder

### "Missing Compliance" won't go away
- Answer the encryption question (usually "No" for most apps)
- If your app uses custom encryption beyond HTTPS, consult Apple docs

### TestFlight says "No Builds Available"
- Build is still processing (wait 10-30 min)
- Build failed compliance (check email for details)
- Make sure build is added to your test group

---

## Quick Reference Commands

Open project in Xcode from Terminal:
```bash
open /Users/mario/Personal/AI\ Apps/kanji-memory-ios/KanjiMemory.xcodeproj
```

---

## Checklist Summary

### Developer Portal
- [ ] Created App ID with Sign In with Apple capability
- [ ] Bundle ID: `com.yourname.penguinsensei`

### App Store Connect
- [ ] Created new app
- [ ] Selected correct Bundle ID

### Xcode
- [ ] Updated Bundle Identifier to match
- [ ] Enabled automatic signing
- [ ] Selected your team
- [ ] Verified Sign In with Apple capability
- [ ] Set version to 1.0.0, build to 1
- [ ] Selected "Any iOS Device (arm64)"
- [ ] Archived successfully
- [ ] Uploaded to App Store Connect

### TestFlight
- [ ] Build finished processing
- [ ] Answered export compliance
- [ ] Created internal test group
- [ ] Added yourself as tester
- [ ] Installed via TestFlight app on iPhone

---

## Next Upload (Future Builds)

For subsequent builds:
1. Increment **Build** number (1 → 2 → 3...)
2. Product → Archive
3. Distribute App → Upload
4. New build appears in TestFlight automatically
5. Testers get notified of update

---

**Questions?** The Apple Developer documentation is helpful:
- https://developer.apple.com/testflight/
- https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
