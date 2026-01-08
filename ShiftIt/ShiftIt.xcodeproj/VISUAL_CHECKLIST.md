# Visual Xcode Configuration Checklist

## Step-by-Step with Screenshots Reference

This document describes exactly what you should see in Xcode at each step.

---

## ✅ Step 1: Verify Files in Project Navigator

### What to Check
Look at your Project Navigator (left sidebar, folder icon).

### Should Look Like:
```
▾ ShiftIt
  ▾ ShiftIt
    ▸ Resources
    ▸ Classes
      ShiftItAppDelegate.h
      ShiftItAppDelegate.m
      PreferencesWindowController.h
      PreferencesWindowController.m
      KeyboardShortcutRecorder.swift       ← Must be here
      ShiftIt-Bridging-Header.h            ← Must be here
      ... other files ...
```

### How to Fix if Missing:
- Right-click on "ShiftIt" folder
- Choose "Add Files to ShiftIt..."
- Navigate to and select the missing files
- **Important**: Check "Add to targets: ShiftIt"
- Click Add

---

## ✅ Step 2: Check File Target Membership

### What to Check
1. Click on `KeyboardShortcutRecorder.swift` in Project Navigator
2. Open **File Inspector** (right sidebar, first icon 📄)
3. Look at **Target Membership** section

### Should Look Like:
```
Target Membership
☑️ ShiftIt             ← Must be checked!
```

### How to Fix:
- If unchecked, click the checkbox
- File will now be compiled

---

## ✅ Step 3: Configure Build Settings - Bridging Header

### What to Check
1. Click on project (blue icon at top of Project Navigator)
2. Select **ShiftIt** target (in the targets list)
3. Click **Build Settings** tab
4. Make sure **"All"** and **"Combined"** are selected (not "Basic")
5. In search box, type: `bridging`

### Should Look Like:
```
Swift Compiler - General
  ↳ Objective-C Bridging Header
    Debug   : ShiftIt/ShiftIt-Bridging-Header.h
    Release : ShiftIt/ShiftIt-Bridging-Header.h
```

### How to Fix:
- Double-click the value field
- Type: `ShiftIt/ShiftIt-Bridging-Header.h`
- Press Enter
- Try building - if error, try: `$(PROJECT_DIR)/ShiftIt/ShiftIt-Bridging-Header.h`

---

## ✅ Step 4: Configure Build Settings - Defines Module

### What to Check
1. Still in Build Settings
2. Clear search box
3. Type: `defines module`

### Should Look Like:
```
Packaging
  ↳ Defines Module
    Debug   : Yes         ← Must be Yes!
    Release : Yes         ← Must be Yes!
```

### How to Fix:
- Double-click the value
- Change to "Yes"
- Or click and select "Yes" from dropdown

---

## ✅ Step 5: Verify Swift Language Version

### What to Check
1. In Build Settings, type: `swift lang`

### Should Look Like:
```
Swift Compiler - Language
  ↳ Swift Language Version
    Debug   : Swift 5
    Release : Swift 5
```

### Acceptable Values:
- Swift 5 (preferred)
- Swift 5.x (any version)

### How to Fix:
- Click the dropdown
- Select the latest Swift version available

---

## ✅ Step 6: Check Product Module Name

### What to Check
1. In Build Settings, type: `product module`

### Should Look Like:
```
Packaging
  ↳ Product Module Name
    Debug   : ShiftIt       ← Note this name!
    Release : ShiftIt
```

### Important:
- This determines the generated header name
- If it says "ShiftIt" → header is `ShiftIt-Swift.h`
- If it says "ShiftItApp" → header is `ShiftItApp-Swift.h`
- Usually you should **not change** this

---

## ✅ Step 7: Clean Build Phases

### What to Check
1. Still in target settings
2. Click **Build Phases** tab
3. Expand **"Compile Sources"**

### Should Look Like:
```
▾ Compile Sources (XX items)
  ShiftItAppDelegate.m
  PreferencesWindowController.m
  KeyboardShortcutRecorder.swift    ← Must be here!
  ... other .m and .swift files ...
```

### What to Look For (BAD SIGNS):
- ❌ Any file in red
- ❌ A file called "Yes"
- ❌ Any file with "(missing)" next to it
- ❌ Duplicate entries

### How to Fix:
- Select bad entry
- Click **-** button (bottom left)
- Delete it
- If KeyboardShortcutRecorder.swift is missing, click **+** and add it

---

## ✅ Step 8: Check Copy Bundle Resources

### What to Check
1. Still in Build Phases
2. Expand **"Copy Bundle Resources"**

### Should Look Like:
```
▾ Copy Bundle Resources (XX items)
  Assets.xcassets
  PreferencesWindow.xib
  ... resource files only ...
```

### What to Look For (BAD SIGNS):
- ❌ Any .swift files (shouldn't be here!)
- ❌ Any .h files (shouldn't be here!)
- ❌ Any red files
- ❌ A file called "Yes"

### How to Fix:
- Remove any source files from here
- Only resources (.xib, .xcassets, images, etc.) belong here

---

## ✅ Step 9: Clean Build

### What to Do
1. In Xcode menu: **Product** → **Clean Build Folder**
2. Or press: **⇧⌘K** (Shift-Command-K)
3. Wait for it to complete

### Should See:
- A brief progress bar
- Message: "Clean Succeeded"

---

## ✅ Step 10: Close and Reopen Xcode

### What to Do
1. **Xcode** → **Quit Xcode** (or ⌘Q)
2. Wait a few seconds
3. Open Xcode again
4. Open your project

### Why:
- Forces Xcode to regenerate its internal caches
- Ensures build settings are properly loaded
- Clears any stale state

---

## ✅ Step 11: Build the Project

### What to Do
1. **Product** → **Build**
2. Or press: **⌘B**

### Should See:
```
Build ShiftIt: All issues
  ⚙️ Compiling ShiftItAppDelegate.m
  ⚙️ Compiling PreferencesWindowController.m
  ⚙️ Compiling Swift sources...
  ⚙️ Compiling KeyboardShortcutRecorder.swift
  ⚙️ Emitting module for ShiftIt
  ⚙️ Linking ShiftIt
  ✅ Build Succeeded
```

### If It Fails:
- Look at the **first error** (scroll up in build log)
- Ignore subsequent cascade errors
- Check the error against **[BUILD_ERROR_FIXES.md](BUILD_ERROR_FIXES.md)**

---

## ✅ Step 12: Verify Generated Header

### What to Do (Terminal)
```bash
find ~/Library/Developer/Xcode/DerivedData/ShiftIt-* \
  -name "*-Swift.h" \
  -print \
  -exec ls -lh {} \;
```

### Should See:
```
.../DerivedData/ShiftIt-.../Build/.../ShiftIt-Swift.h
-rw-r--r--  1 user  staff   45K Jan 2 19:00 ShiftIt-Swift.h
```

### If Not Found:
- Build didn't complete successfully
- Check for build errors
- Make sure "Defines Module" is YES
- Try cleaning and building again

---

## ✅ Step 13: Test the App

### What to Do
1. Run the app (⌘R)
2. Open Preferences (⌘,)
3. Click "Hotkeys" tab

### Should See:
```
Action          Shortcut
───────────────────────────────────────
Left            [Click to record shortcut]
Right           [Click to record shortcut]
Top             [Click to record shortcut]
...
```

### Should NOT See:
```
❌ "Keyboard shortcuts handled by KeyboardShortcutManager"
❌ "Setup required: Check KEYBOARD_SHORTCUT_INTEGRATION.md"
❌ Red placeholder text
```

### Test Recording:
1. Click on any "Click to record shortcut" field
2. Field border should turn blue
3. Press ⌘⌥← (Command-Option-Left)
4. Should display as: "⌥⌘←"
5. Shortcut is now saved

---

## 🎯 Visual Indicators of Success

### In Xcode:

**Project Navigator:**
- ✅ No red files
- ✅ KeyboardShortcutRecorder.swift is visible
- ✅ All files have proper icons

**Build Settings:**
- ✅ No warnings in the settings
- ✅ Bridging header path is blue (valid)
- ✅ Defines Module is "Yes"

**Build Phase:**
- ✅ All files are black (not red)
- ✅ No "(missing)" labels
- ✅ Swift file in Compile Sources

**Build Output:**
- ✅ "Compiling Swift sources..."
- ✅ "Build Succeeded"
- ✅ 0 Errors, 0 Warnings (ideally)

### In Running App:

**Preferences Window:**
- ✅ Interactive shortcut fields
- ✅ Clicking activates recording
- ✅ Border turns blue when recording
- ✅ Shortcuts display with proper symbols
- ✅ Clear button (X) appears when set

**Functionality:**
- ✅ Recording works
- ✅ Shortcuts save automatically
- ✅ Shortcuts persist after app relaunch
- ✅ Window actions trigger with shortcuts
- ✅ Menu shows keyboard equivalents

---

## 🔴 Visual Indicators of Problems

### In Xcode:

**Red Flags:**
- ❌ Red files in Project Navigator
- ❌ Red text in Build Settings
- ❌ Red errors in Issue Navigator
- ❌ "(missing)" next to filenames
- ❌ "Build Failed" message

**Common Error Patterns:**
```
❌ "Use of undeclared type 'KeyboardShortcutRecorder'"
   → Swift not being compiled or bridged

❌ "No such module 'ShiftIt'"
   → Defines Module is not YES

❌ "Bridging header 'ShiftIt/ShiftIt-Bridging-Header.h' does not exist"
   → Path is wrong or file is missing

❌ "Build input file cannot be found: '.../Yes'"
   → Corrupted Build Phase entry
```

### In Running App:

**Warning Signs:**
- ❌ Placeholder text instead of recorders
- ❌ Non-interactive fields
- ❌ Red error messages
- ❌ "Setup required" messages
- ❌ Can't record shortcuts

---

## 📊 Build Configuration Comparison

### ❌ Before (Not Working)

```
Build Settings:
├─ Defines Module: NO
├─ Bridging Header: (empty)
└─ Swift Lang: (not set)

Build Phases:
├─ Compile Sources: (Swift file missing)
└─ Copy Resources: (has bad entry "Yes")

Result:
└─ Errors about forward class, can't find properties
```

### ✅ After (Working)

```
Build Settings:
├─ Defines Module: YES
├─ Bridging Header: ShiftIt/ShiftIt-Bridging-Header.h
└─ Swift Lang: Swift 5

Build Phases:
├─ Compile Sources: (includes .swift file)
└─ Copy Resources: (resources only)

Result:
└─ Builds successfully, app works!
```

---

## 🎓 Understanding What Each Setting Does

### Defines Module (YES)
- **Purpose**: Tells Xcode this target is a module
- **Effect**: Enables Swift→ObjC bridging
- **Required**: YES for mixed Swift/ObjC projects

### Bridging Header
- **Purpose**: Lists ObjC headers to expose to Swift
- **Effect**: Swift code can use ObjC classes
- **Format**: Path relative to .xcodeproj

### Product Module Name
- **Purpose**: Name of the compiled module
- **Effect**: Determines Swift header name
- **Example**: "ShiftIt" → "ShiftIt-Swift.h"

### Swift Language Version
- **Purpose**: Which Swift version to compile with
- **Effect**: Available language features
- **Recommendation**: Latest stable (Swift 5+)

---

## 💡 Pro Tips

### Tip 1: Use Xcode's Search
Don't scroll through Build Settings - use the search box!
- Type "bridging" to find bridging header
- Type "module" to find module settings
- Type "swift" to find Swift settings

### Tip 2: Check Both Configurations
Some settings differ between Debug and Release:
- Make sure both are set correctly
- Use "Combined" view to set both at once

### Tip 3: Save Known-Good State
Once it works:
```bash
git add ShiftIt.xcodeproj/project.pbxproj
git commit -m "Working Xcode configuration"
```

### Tip 4: Watch Build Output
Don't just look at errors - watch the build progress:
- "Compiling Swift sources" means Swift is being built
- No Swift messages means it's not being compiled

### Tip 5: Test Incrementally
After each change:
1. Clean (⇧⌘K)
2. Build (⌘B)
3. Check if it helped

Don't make multiple changes before testing!

---

## 🎉 Success Checklist

Mark these off as you complete them:

- [ ] Files exist in Project Navigator
- [ ] Target membership checked for Swift file
- [ ] Bridging header path set correctly
- [ ] Defines Module = YES
- [ ] Swift Language Version = Swift 5+
- [ ] No bad files in Build Phases
- [ ] Cleaned build folder
- [ ] Closed and reopened Xcode
- [ ] Build succeeds (⌘B)
- [ ] Generated Swift header exists
- [ ] App runs without crashing
- [ ] Preferences shows interactive recorders
- [ ] Can record a shortcut
- [ ] Shortcut displays correctly
- [ ] Shortcut triggers action
- [ ] Shortcut persists after relaunch

---

**Once all are checked, you're done!** 🎊
