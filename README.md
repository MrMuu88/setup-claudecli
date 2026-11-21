# setup-claudecli

PowerShell script a [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) CLI Windowsos telepítéséhez és integrálásához.

## Miért kényelmes így?

Az AI-asszisztensek használata általában egy külön alkalmazással kezdődik: megnyitsz egy chatablakot vagy egy fejlesztői környezetet, majd oda töltöd fel vagy ott nyitod meg a fájljaidat. A munka így az eszköz logikája szerint folyik, nem a tiéd szerint.

Ez a script megfordítja ezt a sorrendet. **A Claude oda jön, ahol a fájljaid vannak.**

- **Nincs szükség külön keretprogramra.** Nem kell IDE-t, projektkezelőt vagy webes felületet nyitni. Egy Windows Terminal ablak és a Claude CLI elég.
- **A fájljaidat a saját logikád szerint rendezed.** Nem kell projektekbe importálni vagy egy adott mappastruktúrához igazodni. Ugyanazokat a mappákat használod, amelyeket eddig is: dokumentumokat, jegyzeteket, forráskódot vagy bármi mást.
- **A megszokott fájlkezelőből szinte azonnal elérhető.** Az intézőben jobb klikk egy mappára vagy egy mappa üres területére, majd **„Open claude here”**. A Claude már abban a mappában indul, és látja a benne lévő fájlokat. Egy kattintás, és dolgozhatsz is vele.

Így a Claude a Windows része lesz: egy eszköz a kezed ügyében, amelyet bárhol elővehetsz, ahol éppen dolgozol.

## Mit csinál?

1. **Claude CLI telepítése:** ha a `claude` nincs telepítve, felteszi a hivatalos telepítővel, majd ellenőrzi, hogy a mappája (`%USERPROFILE%\.local\bin`) benne van-e a PATH-ban. Ha nincs, hozzáadja a felhasználói PATH-hoz.
2. **Windows Terminal profil:** létrehoz egy **„Claude Code”** profilt, ha még nincs ilyen.
3. **Intéző helyi menü:** felvesz egy **„Open claude here”** menüpontot. Mappára vagy a mappa üres területére jobb klikkelve a Windows Terminal a fenti profillal, az adott mappában indítja a Claude CLI-t.

Rendszergazdai jog **nem kell**: minden az aktuális felhasználó profiljában és a `HKCU` registry-ágban történik.

## Követelmények

- Windows 10/11
- Windows PowerShell 5.1 vagy PowerShell 7+
- [Windows Terminal](https://aka.ms/terminal) (`winget install --id Microsoft.WindowsTerminal -e`)

## Használat

Teljes telepítés:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-claudecli.ps1
```

Ha csak a függvényeket szeretnéd betölteni, és egyenként futtatni őket:

```powershell
. .\setup-claudecli.ps1 -NoRun
Install-ClaudeCli
Register-ClaudeTerminalProfile
Register-ClaudeContextMenu
```

A telepítés után nyiss új terminált, vagy indítsd újra a Windows Terminalt.

## Függvények

| Függvény | Leírás |
|---|---|
| `Install-ClaudeCli` | Ellenőrzi és szükség esetén telepíti a Claude CLI-t, majd felveszi a mappáját a PATH-ba. |
| `Register-ClaudeTerminalProfile` | Létrehozza a „Claude Code” Windows Terminal profilt. |
| `Register-ClaudeContextMenu` | Létrehozza az „Open claude here” menüpontot mappákra és a mappák hátterére. |
| `Install-ClaudeIntegration` | Az összefogó függvény, amely a fentieket a megfelelő sorrendben futtatja. |
| `Unregister-ClaudeContextMenu` | Eltávolítja a helyi menü bejegyzéseket. |

## Részletek

- **Terminal profil:** a profil [JSON fragmentként](https://learn.microsoft.com/windows/terminal/json-fragment-extensions) kerül ide: `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\ClaudeCode\claude.json`. A `settings.json` változatlan marad. A profil PowerShellt indít, abban fut a `claude`, így kilépés után a tab nyitva marad.
- **Registry kulcsok:**
  - `HKCU\Software\Classes\Directory\shell\OpenClaudeHere`
  - `HKCU\Software\Classes\Directory\Background\shell\OpenClaudeHere`
- **Windows 11:** a menüpont a klasszikus helyi menüben jelenik meg, vagyis a „További beállítások megjelenítése” alatt vagy Shift+F10-re.

## Eltávolítás

```powershell
. .\setup-claudecli.ps1 -NoRun
Unregister-ClaudeContextMenu
Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows Terminal\Fragments\ClaudeCode" -Recurse
```
