# Logo and Asset Instructions

## Custom Logo Placement

Place your SignBridge logo files in the following directory:

```
client/assets/images/
```

### Required Logo Files:
- `signbridge_logo.png` - Main logo (recommended: 512x512px, transparent background)
- `signbridge_mark.png` - Compact logo mark (recommended: 128x128px, transparent background)

### Current Placeholders:
The app currently uses a placeholder icon (accessibility_new) with the SignBridge brand colors. Once you add your logo files, update the following files to use them:

1. **Splash Screen** (`lib/features/splash/splash_screen.dart`)
   - Replace the icon container with: `Image.asset('assets/images/signbridge_logo.png')`

2. **Login Screen** (`lib/features/auth/login_screen.dart`)
   - Replace the icon container with: `Image.asset('assets/images/signbridge_logo.png')`

3. **Navigation** (`lib/app/widgets/app_navigation.dart`)
   - Replace the icon in desktop navigation with: `Image.asset('assets/images/signbridge_mark.png', width: 32, height: 32)`

### Brand Colors Used:
- Primary Background: `#12141C`
- Secondary Surface: `#1B1E2A`
- Gold: `#E8A93B`
- Teal: `#2FA0A0`
- Ivory: `#F3F1EA`

Ensure your logo complements these brand colors.
