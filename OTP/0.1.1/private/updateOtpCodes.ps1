function updateOtpCodes {
    param(
        [Parameter(Mandatory)]
        [array]$inputCodes
    )
    
    try {
        $updatedCodes = foreach ($code in $inputCodes) {
            # Create base object with common properties
            $updatedCode = [PSCustomObject]@{
                Algorithm = $code.Algorithm
                HashAlgorithm = $code.HashAlgorithm
                Seed = $code.Seed
                PSTypeName = 'OTP.Code'
                TagDisplay = if ($code.Tag) { $code.Tag -join ', ' } else { '' }
            }

            # Add Tag property if it exists
            if ($code.Tag) {
                Add-Member -InputObject $updatedCode -MemberType NoteProperty -Name 'Tag' -Value $code.Tag
            }

            # Generate new code based on algorithm
            if ($code.Algorithm -eq 'TOTP') {
                $secretBytes = [OtpNet.Base32Encoding]::ToBytes($code.Seed)
                $otp = [OtpNet.Totp]::new($secretBytes, 30, [OtpNet.OtpHashMode]::$($code.HashAlgorithm))
                Add-Member -InputObject $updatedCode -MemberType NoteProperty -Name 'Code' -Value $otp.ComputeTotp()
            }
            else {
                # For HOTP, keep the original code
                Add-Member -InputObject $updatedCode -MemberType NoteProperty -Name 'Code' -Value $code.Code
                Add-Member -InputObject $updatedCode -MemberType NoteProperty -Name 'Counter' -Value $code.Counter
            }

            $updatedCode
        }

        if ($VerbosePreference -eq 'Continue') {
            Write-Verbose "Updated $(($updatedCodes | Where-Object { $_.Algorithm -eq 'TOTP' }).Count) TOTP codes at $(Get-Date -Format 'HH:mm:ss')"
            foreach ($code in $updatedCodes) {
                Write-Verbose "Code for seed $($code.Seed): $($code.Code)"
            }
        }

        return $updatedCodes
    }
    catch {
        Write-Error "Failed to update codes: $_"
        return $inputCodes # Return original codes on error
    }
} 