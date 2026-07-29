# Store listing graphics

| File | Size | Use |
|------|------|-----|
| `feature_graphic_1024x500.png` | 1024×500 | Google Play **feature graphic** |
| `wordmark_512.png` | 512×512 | Optional icon / marketing tile |

Regenerate the feature graphic (from `apps/mobile`):

```powershell
python tool/generate_feature_graphic.py
```

Output: `docs/store-assets/feature_graphic_1024x500.png`.

Phone screenshots: follow `docs/SCREENSHOT_WALKTHROUGH.md` and  
`apps/mobile/tool/screenshot-walkthrough.ps1`.

## Capture tips

- `SCREENSHOT_MODE=true` skips parent PIN and shows a home banner.  
- Triple-tap the 🔒 lock on child home: enables screenshot mode + seeds **Amani**.  
- Free-only build: all stages 1–10 unlocked, no IAP UI.  
- Listing copy: `docs/STORE_LISTING.md` (paste-ready EN/FR/SW).  
