# One-Time Password (OTP) Guide

## Introduction
One-Time Passwords (OTP) are temporary passwords that are valid for only one login session or transaction. They provide an additional layer of security beyond traditional static passwords, implementing a crucial component of two-factor authentication (2FA).

## Key Concepts and Terminology

### Types of OTP
1. **HOTP (HMAC-based One-Time Password)**
   - Counter-based algorithm
   - Uses a shared secret key and an incrementing counter
   - Generates passwords that are valid until used
   - Defined in RFC 4226

2. **TOTP (Time-based One-Time Password)**
   - Time-based algorithm
   - Uses a shared secret key and current timestamp
   - Generates passwords that expire after a time interval (typically 30 seconds)
   - Defined in RFC 6238
   - Most commonly used in modern 2FA implementations

### Seed (Secret Key)
- A shared secret key used to generate OTP codes
- Usually a random sequence of bytes
- Commonly encoded in Base32 format for user-friendly representation
- Must be securely stored and transmitted
- Typical length: 20 bytes (160 bits) or more

### Algorithm Components
- **HMAC**: Hash-based Message Authentication Code
- **Hash Functions**: SHA-1, SHA-256, SHA-512
- **Counter**: 8-byte (64-bit) unsigned integer
- **Time Step**: Usually 30 seconds for TOTP
- **Code Length**: Usually 6-8 digits

## Implementation Approaches

### Using OTP.NET Library
#### Pros:
- Well-tested, production-ready implementation
- Handles edge cases and security considerations
- Regular updates and community support
- Easy to maintain

#### Cons:
- External dependency
- May require additional deployment steps
- Less control over implementation details

#### Example Code (Using OTP.NET):
```powershell
# Generate a random seed
$seed = [byte[]]::new(20)
[Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($seed)
$base32Seed = [OtpNet.Base32Encoding]::ToString($seed)

# Generate TOTP code
$totp = [OtpNet.Totp]::new([OtpNet.Base32Encoding]::ToBytes($base32Seed))
$code = $totp.ComputeTotp()
```

### Independent Implementation
#### Pros:
- Complete control over implementation
- No external dependencies
- Better understanding of the algorithm
- Easier deployment

#### Cons:
- More complex to implement correctly
- Requires thorough testing
- Security vulnerabilities if not implemented properly
- Higher maintenance burden

#### Example Code (Independent Implementation):
```powershell
# Generate a random seed
function New-OTPSecret {
    $seed = [byte[]]::new(20)
    [Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($seed)
    [Convert]::ToBase32String($seed)
}

# TOTP Implementation (simplified)
function Get-TOTPCode {
    param([string]$Secret)
    $timeStep = 30
    $unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $timeCounter = [math]::Floor($unixTime / $timeStep)
    $counter = [BitConverter]::GetBytes([int64]$timeCounter)
    [Array]::Reverse($counter)
    
    $hmac = [Security.Cryptography.HMACSHA1]::new([Convert]::FromBase32String($Secret))
    $hash = $hmac.ComputeHash($counter)
    $offset = $hash[-1] -band 0xf
    
    $code = (($hash[$offset] -band 0x7f) -shl 24) -bor
            (($hash[$offset + 1] -band 0xff) -shl 16) -bor
            (($hash[$offset + 2] -band 0xff) -shl 8) -bor
            ($hash[$offset + 3] -band 0xff)
    
    ($code % 1000000).ToString('D6')
}
```

## OTP URI Format and Structure

### Overview
The OTP URI format is a standardized way to encode OTP configuration information, typically used in QR codes for easy setup in authenticator apps. The format follows this structure:

```
otpauth://TYPE/LABEL?PARAMETERS
```

### Components

1. **Scheme** (Required)
   - Must be `otpauth://`
   - Registered scheme for authenticator apps

2. **Type** (Required)
   - Values: `totp` or `hotp`
   - Specifies whether it's time-based (TOTP) or counter-based (HOTP)

3. **Label** (Required)
   - Format: `Issuer:AccountName`
   - Both components should be URL-encoded
   - Examples:
     - `Example:alice@google.com`
     - `Company%20Name:john.doe@example.com`
   - The label helps users identify the account in their authenticator app

4. **Parameters** (Query String)

   a. **secret** (Required)
   - Base32 encoded secret key
   - Example: `secret=JBSWY3DPEHPK3PXP`
   - Must not include padding characters

   b. **issuer** (Strongly Recommended)
   - URL-encoded service or organization name
   - Should match the issuer in the label
   - Example: `issuer=Example`
   - Helps prevent account collisions

   c. **algorithm** (Optional)
   - Hash algorithm for OTP generation
   - Values: `SHA1` (default), `SHA256`, `SHA512`
   - Example: `algorithm=SHA256`

   d. **digits** (Optional)
   - Number of digits in the OTP
   - Values: `6` (default), `7`, `8`
   - Example: `digits=8`

   e. **period** (Optional, TOTP only)
   - Time step in seconds
   - Default: 30 seconds
   - Common values: 15, 30, 60
   - Example: `period=60`

   f. **counter** (Required for HOTP only)
   - Initial counter value
   - Example: `counter=0`

### Complete Example
```
otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=6&period=30
```

### Security Considerations

1. **Secret Protection**
   - The secret parameter is sensitive and should never be shared
   - Avoid using online QR generators that might log the secret
   - Generate and transmit secrets securely

2. **URI Encoding**
   - Always URL-encode the issuer and account name
   - Handle special characters properly
   - Ensure proper escaping of parameters

3. **Compatibility**
   - Some authenticator apps may ignore certain parameters
   - Always include both label and issuer parameter
   - Test with target authenticator apps

### Best Practices

1. **Issuer Usage**
   - Always provide an issuer in both label and parameters
   - Use consistent issuer names across your service
   - Keep issuer names short but descriptive

2. **Account Names**
   - Use email addresses or usernames that users recognize
   - Include enough information to identify the account
   - Avoid sensitive information in account names

3. **Parameters**
   - Use default values unless there's a specific need
   - Document non-default parameter choices
   - Test compatibility when using non-default values

## Essential References

### Standards and RFCs
1. [RFC 4226](https://tools.ietf.org/html/rfc4226) - HOTP: An HMAC-Based One-Time Password Algorithm
2. [RFC 6238](https://tools.ietf.org/html/rfc6238) - TOTP: Time-Based One-Time Password Algorithm
3. [RFC 4648](https://tools.ietf.org/html/rfc4648) - Base-N Encodings
4. [RFC 2104](https://tools.ietf.org/html/rfc2104) - HMAC: Keyed-Hashing for Message Authentication

### Libraries and Tools
1. [OTP.NET](https://github.com/kspearrin/Otp.NET) - .NET Library for OTP Generation
2. [Google Authenticator](https://github.com/google/google-authenticator) - Reference Implementation
3. [FreeOTP](https://freeotp.github.io/) - Open Source OTP Client

### Security Considerations
1. [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html) - Digital Identity Guidelines
2. [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) 