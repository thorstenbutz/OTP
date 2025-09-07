## The Base32 encoded seed

<img align="right" src="../media/mysigninsmicrosoft_demo2.png" border=1>

Converting bytes to binary representation:

```powershell
function convertToBinaryString {
    param(
        [Parameter(Mandatory)]
        [byte]$Byte
    )
    
    $result = ''
    for ($i = 7; $i -ge 0; $i--) {
        $bit = $Byte -band [Math]::Pow(2, $i)
        $result += if ($bit -gt 0) { '1' } else { '0' }
    }
    
    $result
}

## Example:
$byte = [byte[]]::new(1)
$binaryString = convertToBinaryString -Byte $byte[0]
## Output: 00000000
```

The RFC 4648 Base32 alphabet is defined as follows:

|          |          |          |          |          |          |          |          |
|----------|----------|----------|----------|----------|----------|----------|----------|
| A        | B        | C        | D        | E        | F        | G        | H        |
| I        | J        | K        | L        | M        | N        | O        | P        |
| Q        | R        | S        | T        | U        | V        | W        | X        |
| Y        | Z        | 2        | 3        | 4        | 5        | 6        | 7        |

Each character represents 5 bits:

| Char | Binary | Char | Binary | Char | Binary | Char | Binary |
|------|--------|------|--------|------|--------|------|--------|
| A    | 00000  | I    | 01000  | Q    | 10000  | Y    | 11000  |
| B    | 00001  | J    | 01001  | R    | 10001  | Z    | 11001  |
| C    | 00010  | K    | 01010  | S    | 10010  | 2    | 11010  |
| D    | 00011  | L    | 01011  | T    | 10011  | 3    | 11011  |
| E    | 00100  | M    | 01100  | U    | 10100  | 4    | 11100  |
| F    | 00101  | N    | 01101  | V    | 10101  | 5    | 11101  |
| G    | 00110  | O    | 01110  | W    | 10110  | 6    | 11110  |
| H    | 00111  | P    | 01111  | X    | 10111  | 7    | 11111  |
