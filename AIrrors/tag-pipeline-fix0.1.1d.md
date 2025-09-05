# Tag Pipeline Handling Fix - OTP Module v0.1.1

## Problem Description

When using `Get-OTPCode` with both `-Tag` and `-IncludePath` in a pipeline scenario with multiple files, the tag array accumulated paths from all previous files instead of keeping each file's path separate.

Example of the issue:
```powershell
Get-ChildItem -Path '.\media\*.png' | Read-OTPQRCode | Get-OTPCode -IncludePath -Tag 'foo'
```

## Root Cause

The original code was appending paths to the same `$Tag` array across all pipeline iterations:

```powershell
# Original problematic code
if ($PSBoundParameters.ContainsKey('Path') -and $IncludePath) {
    if ($Tag) {
        $Tag = @($Tag) + $Path  # Accumulating paths across iterations
    }
    else {
        $Tag = @($Path)
    }
}
```

This caused the `$Tag` array to grow with each file processed in the pipeline, leading to each result containing paths from all previous files.

## Fixed Code

```powershell
# Create new tags array for each iteration
$currentTags = @()
if ($Tag) {
    $currentTags += $Tag
}
if ($PSBoundParameters.ContainsKey('Path') -and $IncludePath) {
    $currentTags += $Path
}

# Use currentTags when adding properties
if ($currentTags.Count -gt 0) {
    Add-Member -InputObject $result -MemberType NoteProperty -Name 'Tag' -Value $currentTags
    if ($ShowUI -or $ForceConsole) {
        Add-Member -InputObject $result -MemberType NoteProperty -Name 'TagDisplay' -Value ($currentTags -join ', ')
    }
}
```

## Why This Fix Works

1. Creates a new `$currentTags` array for each pipeline item
2. Adds user-provided tags first (if any)
3. Adds current file's path (if -IncludePath is specified)
4. Each result gets its own independent set of tags

## Test Cases and Results

```powershell
# Test 1: Single file
Get-ChildItem ".\media\*.png" | Select-Object -First 1 | Read-OTPQRCode | Get-OTPCode -IncludePath -Tag "TestTag"
Result: Tag = {TestTag, D:\git\OTP\media\FooBar_demo.png}

# Test 2: Multiple files
Get-ChildItem ".\media\*.png" | Read-OTPQRCode | Get-OTPCode -IncludePath -Tag "TestTag"
Result: Each file gets its own tags + path

# Test 3: Multiple user tags
Get-ChildItem ".\media\*.png" | Read-OTPQRCode | Get-OTPCode -IncludePath -Tag "TestTag1", "TestTag2"
Result: Tag = {TestTag1, TestTag2, <current_file_path>}
```

## Impact

- Each QR code result now contains only its relevant tags
- User-provided tags are preserved for all results
- File paths are correctly associated with their respective QR codes
- No cross-contamination of tags between pipeline items

## Lesson Learned

When handling pipeline input with arrays:
1. Create new arrays for each pipeline item
2. Don't modify parameter arrays directly
3. Keep pipeline item data isolated
4. Test with multiple items in pipeline
5. Consider both single and multiple input scenarios

This fix demonstrates the importance of proper array handling in pipeline scenarios, especially when combining user input with per-item data.


