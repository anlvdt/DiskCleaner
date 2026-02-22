# Implementation Plan: One-Click Safe Clean Bug Fixes

## Tasks

- [x] 1. Fix FmtSize scope issue in SmartClean.ps1
  - Thêm FmtSize function definition vào đầu SmartClean.ps1
  - Đổi tên Clear-RecycleBin-Safe → Invoke-RecycleBinClear
  - Cập nhật call site trong Invoke-OneClickClean
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.4_

- [x] 2. Fix broken regex in FolderOrganizer.ps1
  - Fix regex pattern '^\d{4} → '^\d{4}$' trong Invoke-UndoOrganize
  - Đảm bảo tất cả code blocks được đóng đúng
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 3. Checkpoint - Verify fixes
  - Ensure all modules load without parse errors
  - Ensure One-Click Clean runs to completion
