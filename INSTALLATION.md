# Mercury Installation Guide

## System Requirements

- **macOS**: 11.0 (Big Sur) or later
- **Processor**: Apple Silicon (M1/M2/M3/M4) or Intel
- **Memory**: 4GB RAM minimum
- **Storage**: 500MB free space
- **Dependencies**: Qt6 framework (instructions below)

## Prerequisites

Mercury requires Qt6 framework to be installed on your Mac. This is a one-time installation.

### Installing Qt6 via Homebrew

1. **Install Homebrew** (if not already installed):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install Qt6**:
   ```bash
   brew install qt@6
   ```
   
   This will take 5-10 minutes and requires about 2GB of disk space.

## Installing Mercury

### Step 1: Mount the DMG
1. Double-click `Mercury-Simple.dmg` to mount it
2. A new window will open showing Mercury app and Applications folder

### Step 2: Install the Application
1. Drag the **Mercury** app icon to the **Applications** folder
2. Wait for the copy to complete
3. Eject the DMG by clicking the eject button in Finder

### Step 3: First Launch

**Important**: macOS will block the app on first launch because it's not from the App Store.

1. Open **Finder** → **Applications**
2. Find **Mercury** in your Applications folder
3. **Right-click** (or Control-click) on Mercury
4. Select **Open** from the context menu
5. A security dialog will appear saying "Mercury is from an unidentified developer"
6. Click **Open** to launch the app

After the first launch, you can open Mercury normally from Launchpad or Applications.

## Using Mercury

### First Time Setup
Mercury comes pre-configured with API keys for:
- Statistical data access via Statista
- AI assistance via Claude

No additional configuration needed!

### Features
- **Web Browsing**: Full-featured browser with multiple tabs
- **AI Assistant**: Click "Insights" to open the AI panel
- **Statistical Research**: Ask questions about data and statistics
- **Smart Citations**: Click citation links to open sources

### Keyboard Shortcuts
- `Cmd+T`: New tab
- `Cmd+W`: Close tab
- `Cmd+L`: Focus address bar
- `Cmd+R`: Reload page

## Troubleshooting

### "Mercury can't be opened because it is from an unidentified developer"
- Solution: Right-click the app and select "Open" instead of double-clicking

### "Mercury is damaged and can't be opened"
1. Remove quarantine attribute:
   ```bash
   xattr -cr /Applications/Mercury.app
   ```
2. Try opening again with right-click → Open

### "Library not loaded" or Qt-related errors
- Ensure Qt6 is installed: `brew list qt@6`
- If not installed, run: `brew install qt@6`
- If installed but not working: `brew reinstall qt@6`

### App crashes on launch
1. Check if Qt6 is properly installed:
   ```bash
   ls /opt/homebrew/opt/qt/lib/QtCore.framework
   ```
2. If the path doesn't exist, reinstall Qt6

### Blank window or WebEngine not loading
- This may happen on first launch
- Quit Mercury (Cmd+Q) and relaunch

## Uninstalling

To remove Mercury:
1. Quit Mercury if running
2. Drag Mercury from Applications to Trash
3. Empty Trash

To also remove Qt6 (not recommended if using other Qt apps):
```bash
brew uninstall qt@6
```

## Privacy & Security

- Mercury processes all data locally on your machine
- API communications are encrypted (HTTPS)
- No personal data is stored outside your computer
- Browser data is stored in: `~/Library/Application Support/Mercury`

## Support

For issues or questions:
- Technical problems: Check the Troubleshooting section above
- Feature requests: Contact your Mercury administrator

## Version Information

- App Version: 1.0.0
- Bundle ID: com.statista.answer
- Minimum macOS: 11.0 (Big Sur)

---

*Mercury is a research assistant powered by Statista data and Claude AI*