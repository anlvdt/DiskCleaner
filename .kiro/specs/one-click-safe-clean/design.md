# Design Document: One-Click Safe Clean Bug Fixes

## Overview

Ba lỗi cần fix để One-Click Safe Clean hoạt động đúng:
1. `FmtSize` undefined trong SmartClean runspace
2. `FolderOrganizer.ps1` bị truncate/broken regex
3. Tên hàm `Clear-RecycleBin-Safe` tiềm ẩn conflict

## Architecture

```
DiskCleanerPro.ps1 (UI thread)
  └─ btnOneClick.Click
       └─ Runspace (background)
            ├─ . SystemCleaner.ps1   ← defines Get-SystemJunkTargets, Invoke-CleanTarget
            ├─ . SmartClean.ps1      ← defines Invoke-OneClickClean (calls FmtSize ← BUG HERE)
            └─ FmtSize inline def    ← chỉ có trong script block của DiskCleanerPro, không trong SmartClean scope
```

## Root Cause Analysis

### Bug 1: FmtSize scope issue
`Invoke-OneClickClean` trong `SmartClean.ps1` gọi `FmtSize` ở dòng:
```powershell
[void]$results.Add([PSCustomObject]@{...; Cleaned=FmtSize $cr.Cleaned; ...})
```
Nhưng `FmtSize` chỉ được định nghĩa trong `Scanner.ps1`. Khi runspace của One-Click chỉ dot-source `SystemCleaner.ps1` + `SmartClean.ps1`, `FmtSize` không tồn tại → `CommandNotFoundException`.

**Fix:** Thêm `FmtSize` trực tiếp vào `SmartClean.ps1`.

### Bug 2: FolderOrganizer.ps1 broken regex
Trong `Invoke-UndoOrganize`, đoạn cleanup year folders dùng:
```powershell
Where-Object { $_.Name -match '^\d{4}
```
Regex bị cắt đứt, thiếu closing `}` và `'`. Gây `ParseException` khi module load.

**Fix:** Hoàn chỉnh regex thành `'^\d{4}$'`.

### Bug 3: Clear-RecycleBin-Safe naming
Tên `Clear-RecycleBin-Safe` quá gần với built-in `Clear-RecycleBin`. Đổi thành `Invoke-RecycleBinClear` để tránh confusion và follow PowerShell naming conventions.

## Components and Interfaces

### SmartClean.ps1 changes
- Thêm `FmtSize` function definition ở đầu file
- Đổi tên `Clear-RecycleBin-Safe` → `Invoke-RecycleBinClear`
- Cập nhật call site trong `Invoke-OneClickClean`

### FolderOrganizer.ps1 changes
- Fix regex `'^\d{4}` → `'^\d{4}$'` trong `Invoke-UndoOrganize`

## Data Models

Không thay đổi data models. Chỉ fix function definitions và syntax.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do.*

Property 1: FmtSize always available in SmartClean scope
*For any* call to `Invoke-OneClickClean`, `FmtSize` must be resolvable without importing Scanner.ps1
**Validates: Requirements 1.1, 1.2, 1.3**

Property 2: One-Click Clean completes without exception
*For any* invocation of `Invoke-OneClickClean` in an isolated runspace loading only SystemCleaner + SmartClean, the function must return a result object without throwing
**Validates: Requirements 2.1, 2.2**

Property 3: FolderOrganizer loads without parse error
*For any* dot-source of FolderOrganizer.ps1, PowerShell must parse the file successfully
**Validates: Requirements 3.1, 3.2, 3.3**

## Error Handling

- `Invoke-OneClickClean` đã có try/catch, lỗi được propagate qua `$sh3.Error`
- UI hiển thị error dialog nếu `$sh3.Error` có giá trị
- Không cần thay đổi error handling logic

## Testing Strategy

Manual verification:
1. Load SmartClean.ps1 trong PowerShell session mới (không load Scanner.ps1) → gọi `Invoke-OneClickClean` → không có CommandNotFoundException
2. Dot-source FolderOrganizer.ps1 → không có ParseException
3. Click One-Click Safe Clean trong UI → dialog hiển thị kết quả thành công
