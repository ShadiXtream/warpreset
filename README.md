# Warp Terminal AI Reset - Enhanced 🚀

[![PowerShell](https://img.shields.io/badge/PowerShell-5.0%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows](https://img.shields.io/badge/Windows-10%2B-blue.svg)](https://www.microsoft.com/windows)

## [![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Enhanced PowerShell script to reset Warp Terminal's AI limit counter and relaunch the app while maintaining terminal history.

**Works on Windows 10 & 11**

## ✨ What's New in Enhanced Version

- 🔄 **Automatic path detection** - No more manual path editing
- 🛡️ **Error handling** - Won't break if something goes wrong  
- 📝 **Logging** - See what's happening during cleanup
- 🎯 **Multi-user support** - Works for any user account
- ⚡ **Safer process handling** - Graceful shutdown before force quit

## 🚀 Quick Start

### Simple Usage
```powershell
.\Clean-WarpData.ps1
```

### Test First (Recommended)
```powershell
.\Clean-WarpData.ps1 -WhatIf
```

### For Specific User
```powershell
.\Clean-WarpData.ps1 -UserName "your-username"
```

## 📋 What It Does

1. **Stops** Warp Terminal safely
2. **Cleans** AI usage data and analytics (keeps `warp.sqlite` history)
3. **Restarts** Warp Terminal automatically
4. **Verifies** everything worked correctly

## ⚙️ Options

| Option | Description | Default |
|--------|-------------|---------|
| `-UserName` | Target user (auto-detects if not specified) | Current user |
| `-WaitTimeSeconds` | Wait time after stopping Warp | 3 seconds |
| `-WhatIf` | Preview what will happen without doing it | Off |

## 🔧 Installation

1. **Download** the script
2. **Right-click** → Properties → **Unblock** (if needed)
3. **Run** in PowerShell
4. **Enjoy** a fresh Warp Terminal experience! without limits

Note: It is recommended to close Warp Terminal manually before running the script, but it will handle that for you.

## ❓ Troubleshooting

**Script can't find Warp?**
- The script automatically searches common install locations
- Check if Warp is actually installed

**Permission errors?**
- Run PowerShell as your normal user (admin not needed)
- Make sure Warp isn't running as different user

**Files not getting deleted?**
- Try increasing wait time: `-WaitTimeSeconds 10`
- Some files might be locked - script will skip them safely

## 🆚 vs Original Script

| Feature | Original | Enhanced |
|---------|----------|----------|
| Manual path editing | ❌ Required | ✅ Auto-detection |
| Error handling | ❌ None | ✅ Full coverage |
| Multi-user support | ❌ Hardcoded | ✅ Dynamic |
| Safety checks | ❌ Basic | ✅ Comprehensive |
| Logging | ❌ None | ✅ Detailed |

## 📄 License

## TO DO: Add license information here

---

**Simple. Safe. Effective.** 🎯
