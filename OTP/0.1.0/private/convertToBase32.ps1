function convertToBase32 {
    param($bytes)
    
    # Base32 alphabet: A-Z and 2-7 (32 characters total)
    # Each character represents 5 bits of data (2^5 = 32 possible values)
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    $result = ''
    
    # CRITICAL: Buffer to accumulate bits before converting to Base32
    # We need to handle bits in groups of 5 (Base32) while input is in groups of 8 (bytes)
    $buffer = 0
    $bitsLeft = 0
    
    # Process each input byte (8 bits)
    foreach ($byte in $bytes) {
        # CRITICAL: Add 8 bits to the buffer
        # 1. Shift existing bits left by 8 to make room for new bits
        # 2. OR with new byte to add it to the rightmost position
        $buffer = ($buffer -shl 8) -bor $byte
        $bitsLeft += 8
        
        # CRITICAL: Extract Base32 characters while we have enough bits
        # Each Base32 character needs 5 bits
        while ($bitsLeft -ge 5) {
            $bitsLeft -= 5
            # Extract 5 bits from the buffer:
            # 1. Shift right to get the highest 5 bits
            # 2. AND with 0x1F (31) to get just those 5 bits
            $index = ($buffer -shr $bitsLeft) -band 0x1F
            # Convert to Base32 character
            $result += $alphabet[$index]
        }
    }
    
    # CRITICAL: Handle any remaining bits (less than 5)
    # This ensures we don't lose any data at the end
    if ($bitsLeft -gt 0) {
        # Shift left to align remaining bits
        # AND with 0x1F to get just those bits
        $index = ($buffer -shl (5 - $bitsLeft)) -band 0x1F
        $result += $alphabet[$index]
    }
    
    $result
}

function convertFromBase32 {
    param($base32String)

    # Base32 alphabet: A-Z and 2-7 (32 characters total)
    # Each character represents 5 bits of data (2^5 = 32 possible values)
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
    $byteArray = @()
    
    # CRITICAL: Buffer to accumulate bits before converting to bytes
    # We need to handle bits in groups of 5 (Base32) while output is in groups of 8 (bytes)
    $buffer = 0
    $bitsLeft = 0

    # Remove padding and convert to uppercase
    $base32String = $base32String.ToUpperInvariant() -replace '=+$'

    # Process each Base32 character
    for ($i = 0; $i -lt $base32String.Length; $i++) {
        $char = $base32String[$i]
        # Get the 5-bit value for this character
        $value = $alphabet.IndexOf($char)
        if ($value -eq -1) { continue }

        # CRITICAL: Add 5 bits to the buffer
        # 1. Shift existing bits left by 5 to make room for new bits
        # 2. OR with new value to add it to the rightmost position
        $buffer = ($buffer -shl 5) -bor $value
        $bitsLeft += 5

        # CRITICAL: Extract bytes when we have enough bits
        # Each byte needs 8 bits
        if ($bitsLeft -ge 8) {
            $bitsLeft -= 8
            # Extract 8 bits from the buffer:
            # 1. Shift right to get the highest 8 bits
            # 2. AND with 0xFF (255) to get just those 8 bits
            $byte = ($buffer -shr $bitsLeft) -band 0xFF
            $byteArray += [byte]$byte
        }
    }

    $byteArray
}

