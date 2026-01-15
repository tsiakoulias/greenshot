# Memory Leak Analysis - Greenshot

This document outlines potential memory leaks identified in the Greenshot codebase.

---

## 🔴 High Priority

### 1. Missing `Language.LanguageChanged` Unsubscription

**Affected files:**
- `src/Greenshot.Plugin.Flickr/FlickrPlugin.cs`
- `src/Greenshot.Plugin.Dropbox/DropboxPlugin.cs`
- `src/Greenshot.Plugin.Box/BoxPlugin.cs`
- `src/Greenshot.Plugin.ExternalCommand/ExternalCommandPlugin.cs`

**Issue:** Plugins subscribe to the static `Language.LanguageChanged` event but never unsubscribe in `Shutdown()` or `Dispose()`, keeping plugin instances alive indefinitely.

**Fix:** Add `Language.LanguageChanged -= OnLanguageChanged;` in `Dispose()`.

---

### 2. BidirectionalBinding Missing IDisposable

**File:** `src/Greenshot.Base/Controls/BidirectionalBinding.cs`

**Issue:** Subscribes to `PropertyChanged` events but never implements `IDisposable` to unsubscribe. Objects bound together will keep each other alive indefinitely.

**Fix:** Implement `IDisposable` and unsubscribe from both `PropertyChanged` events.

---

### 3. Static EditorList Never Cleaned

**File:** `src/Greenshot.Editor/Forms/ImageEditorForm.cs`

**Issue:** Editors are added to a static `List<IImageEditor>` but may not be removed when forms close, keeping all editor instances in memory.

**Fix:** Ensure `EditorList.Remove(this)` is called in `Dispose()`.

---

## 🟠 Medium Priority

### 4. Timer Leaks

| File | Issue |
|------|-------|
| `src/Greenshot.Base/Core/Cache.cs` | `CachedItem._timerEvent` never disposed |
| `src/Greenshot.Base/Core/AnimatingForm.cs` | Timer stopped but not disposed in `FormClosing` |

**Fix:** Dispose timers and unsubscribe from `Elapsed`/`Tick` events.

---

### 5. Stream Leaks

| File | Issue |
|------|-------|
| `src/Greenshot.Base/IniFile/CopyData.cs` | `MemoryStream` not in `using` statement (2 locations) |
| `src/Greenshot.Editor/Drawing/SvgContainer.cs` | `_svgContent` MemoryStream never disposed |
| `src/Greenshot.Editor/FileFormatHandlers/IconFileFormatHandler.cs` | Streams may leak if exception occurs |

**Fix:** Wrap streams in `using` statements or ensure proper disposal in `finally` blocks.

---

### 6. runtimeImgurHistory Stores Disposable Items

**File:** `src/Greenshot.Plugin.Imgur/ImgurConfiguration.cs`

**Issue:** `ImgurInfo` objects contain images but aren't disposed when removed from the dictionary.

**Fix:** Call `Dispose()` on `ImgurInfo` before removing from dictionary.

---

### 7. Lambda in Static Constructor

**File:** `src/Greenshot.Plugin.Jira/JiraConnector.cs`

**Issue:** Lambda subscription in static constructor to `CoreConfig.PropertyChanged` creates an eternal subscription that can never be unsubscribed.

**Fix:** Use a named method and implement proper cleanup.

---

## 🟡 Lower Priority

| Issue | File |
|-------|------|
| Uses finalizer instead of IDisposable | `src/Greenshot.Base/Core/TranslationData.cs` |
| Uses `new` instead of `override` for Dispose | `src/Greenshot.Base/Controls/Pipette.cs` |
| ExeIconCache could grow unbounded | `src/Greenshot.Base/Core/PluginUtils.cs` |
