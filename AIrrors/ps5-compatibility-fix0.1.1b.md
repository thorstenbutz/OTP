# PowerShell 5.1 Compatibility Fix - OTP Module v0.1.1

## Problem Description

The QR code generation functionality only works in PowerShell 7 but fails in PowerShell 5.1. This is a significant issue since our module manifest states:
```powershell
PowerShellVersion = '5.1'
```

## Root Cause

The issue likely stems from:
1. Using newer .NET methods not available in .NET Framework (used by PS 5.1)
2. Potential differences in how System.Drawing is handled between .NET Framework and .NET Core

## Areas to Check

1. **System.Drawing Usage**:
   ```powershell
   Add-Type -AssemblyName System.Drawing
   ```
   - PS 5.1 uses .NET Framework's System.Drawing
   - PS 7+ uses .NET Core's System.Drawing.Common

2. **Path Resolution**:
   ```powershell
   [System.IO.Path]::IsPathRooted()
   [System.IO.Path]::GetDirectoryName()
   ```
   - Path handling might differ between versions

3. **Bitmap Handling**:
   ```powershell
   $qrBitmap.Save()
   ```
   - Image saving mechanisms might differ

## Required Changes

1. **Add explicit version check**:
   ```powershell
   if ($PSVersionTable.PSVersion.Major -lt 7) {
       Write-Warning "QR code generation might have limited functionality in PowerShell 5.1"
   }
   ```

2. **Ensure .NET Framework compatibility**:
   ```powershell
   # Check if running under .NET Framework
   $isNetFramework = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription -match "^\.NET Framework"
   ```

3. **Alternative approaches for PS 5.1**:
   - Consider using alternative QR code generation methods for PS 5.1
   - Test fallback mechanisms
   - Document version-specific limitations

## Next Steps

1. Test module thoroughly in PowerShell 5.1
2. Identify specific failing components
3. Implement version-specific code paths if needed
4. Update module documentation to clarify version requirements
5. Consider updating manifest to require PS 7+ if fixes aren't feasible

## Impact

- Users on PowerShell 5.1 cannot use QR code functionality
- This affects Windows environments where PS 7 isn't installed
- Contradicts our stated minimum PowerShell version requirement

## Questions to Address

1. Should we:
   - Fix PS 5.1 compatibility?
   - Update manifest to require PS 7?
   - Provide limited functionality in PS 5.1?

2. What's the target user environment:
   - Enterprise (often PS 5.1)?
   - Modern environments (PS 7 available)?

## Testing Required

Test the following in both PS 5.1 and PS 7:
```powershell
# Basic QR code generation
New-OTPSecret -SaveQRCode "test.png"

# Complex scenario
New-OTPSecret -Length 16 -Tag 'Redmond' -Label 'my:lab@el' -Issuer 'Contoso' -Digits 8 -Period 60 -SaveQRCode 'test.png' -ShowQRCode

# Reading QR codes
Read-OTPQRCode -Path test.png
```

## Lesson Learned

When developing PowerShell modules:
1. Test in all supported PowerShell versions early
2. Consider .NET Framework vs .NET Core differences
3. Document version-specific requirements clearly
4. Implement version checks and appropriate warnings
5. Consider providing fallback mechanisms for older versions

