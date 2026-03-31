
# PowerShell Ultimate Completer 🚀

A data-driven, lightning-fast, and highly customizable argument auto-completer for PowerShell.

Tired of PowerShell not knowing the subcommands and flags for your favorite CLI tools like `adb`, `git`, `fastboot`, or `npm`? **Ultimate Completer** solves this by using a simple, easily extendable JSON dictionary to provide deep, multi-level tab completion with helpful tooltips.

No need to write complex PowerShell completion scripts for every single tool. Just add it to the JSON file, and you're good to go!

## ✨ Features
* **Data-Driven:** All commands, subcommands, flags, and descriptions are stored in a single `completions.json` file.
* **Deep Hierarchy:** Supports endless levels of nested subcommands (e.g., `fastboot flash boot -a`).
* **Smart Tooltips:** Displays descriptions of what each subcommand does right in your terminal menu.
* **Executable Friendly:** Seamlessly handles commands whether you type `adb` or `adb.exe`.

## 📺 Preview
<video src="/preview/video.mp4" width="100%"></video>

<video src="/preview/video2" width="100%"></video>

## ⚠️ Prerequisites: The Golden Rule
**Ultimate Completer handles *arguments*, not the root commands themselves.** For this module to trigger, the base CLI tools you are trying to use (like `git`, `adb`, `fastboot`, `wsl`) **must be installed on your system** and accessible globally.
* Ensure your tools are added to your system's **Environment Variables (`PATH`)**.
* OR, define them as an **Alias** in your PowerShell profile.

*If PowerShell doesn't recognize `fastboot` as a valid command on your system, hitting Tab won't trigger the argument completer!*

## 📦 Installation

The easiest way to install Ultimate Completer is via the [PowerShell Gallery](https://www.powershellgallery.com/packages/UltimateCompleter).

**1. Install the module:**
Open PowerShell and run:
```powershell
Install-Module -Name UltimateCompleter -Scope CurrentUser
```
**2. Add it to your PowerShell Profile:** To make the auto-completion work automatically every time you open a new terminal, you need to import it in your profile.

Open your profile:
```
notepad $PROFILE
```

Add this line to the very end of the file, save, and restart your terminal:

```
Import-Module UltimateCompleter -DisableNameChecking
```

## 🛠️ How It Works (Under the Hood)

The entire logic is powered by the `completions.json` file located inside the module folder. It uses a clean, intuitive structure. Here is a quick example of how an entry looks:

```
  "adb": {
    "subcommands": {
      "sideload": { "description": "Sideloads a package to the device" },
      "install": {
        "description": "Pushes a package to the device and installs it",
        "flags": {
          "-r": "Replace existing application",
          "-d": "Allow version code downgrade",
          "-g": "Grant all runtime permissions"
        }
      },
      "shell": { "description": "Starts a remote shell" },
      "devices": {
        "description": "Prints a list of connected devices",
        "flags": {
          "-l": "List device paths"
        }
      }
```

When you type `adb i<TAB>`, the module instantly reads this JSON and suggests `install` along with its description.

## 🤝 Contributing (Help Build the Ultimate Library!)

This module was built to be expanded by the community. You don't need to know advanced PowerShell to contribute; **you just need to know JSON!**

**How to contribute:**

1.  **Fork** the repository.
    
2.  Open `completions.json`.
    
3.  **Add** your favorite CLI tool using the existing structure (Root command -> Subcommands -> Flags & Descriptions).
    
4.  **Commit** your changes and submit a **Pull Request**.
    

## 📄 License

This project is licensed under the [GPL License](LICENSE).

----------

_Created by [@osmanonurkoc](https://github.com/osmanonurkoc)_
