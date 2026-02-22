# Requirements Document

## Introduction

DiskCleaner Pro có tính năng "One-Click Safe Clean" cho phép người dùng dọn dẹp file rác hệ thống (temp, cache trình duyệt, crash dumps, v.v.) chỉ bằng một cú click. Hiện tại tính năng này bị lỗi do các vấn đề về scope hàm trong runspace, tên hàm conflict, và syntax lỗi trong module FolderOrganizer.

## Glossary

- **One-Click Safe Clean**: Tính năng dọn dẹp tự động an toàn, không đụng đến file cá nhân
- **Runspace**: PowerShell isolated execution context chạy background task
- **FmtSize**: Hàm format kích thước file (bytes → KB/MB/GB)
- **SystemCleaner**: Module xử lý các target dọn dẹp hệ thống
- **SmartClean**: Module điều phối One-Click Clean và Smart Recommendations
- **SafeGuard**: Module bảo vệ file hệ thống khỏi bị xóa nhầm

## Requirements

### Requirement 1: FmtSize phải available trong mọi execution context

**User Story:** As a developer, I want FmtSize to be defined wherever it is called, so that size formatting never throws undefined function errors.

#### Acceptance Criteria

1. THE SmartClean_Module SHALL define FmtSize internally hoặc import nó từ Scanner.ps1 trước khi gọi
2. WHEN Invoke-OneClickClean được gọi trong một runspace mới, THE SmartClean_Module SHALL có FmtSize available trong scope của nó
3. WHEN bất kỳ module nào gọi FmtSize, THE Module SHALL không phụ thuộc vào module khác đã được load trước đó trong cùng runspace

### Requirement 2: One-Click Clean phải hoàn thành không có unhandled exception

**User Story:** As a user, I want One-Click Safe Clean to run successfully, so that I can free up disk space with one click.

#### Acceptance Criteria

1. WHEN người dùng click "One-Click Safe Clean" và confirm, THE System SHALL chạy Invoke-OneClickClean đến completion mà không throw exception
2. WHEN Invoke-OneClickClean hoàn thành, THE System SHALL hiển thị kết quả (dung lượng đã giải phóng) trong dialog
3. IF Invoke-OneClickClean gặp lỗi, THEN THE System SHALL hiển thị error message rõ ràng thay vì crash silently
4. WHEN Clear-RecycleBin-Safe được gọi, THE SystemCleaner_Module SHALL thực thi không conflict với PowerShell built-in cmdlets

### Requirement 3: FolderOrganizer phải có syntax hợp lệ

**User Story:** As a developer, I want all modules to load without syntax errors, so that the application starts reliably.

#### Acceptance Criteria

1. THE FolderOrganizer_Module SHALL load mà không có parse error
2. WHEN Invoke-UndoOrganize được gọi, THE FolderOrganizer_Module SHALL xử lý year-folder cleanup với regex hợp lệ
3. THE FolderOrganizer_Module SHALL có tất cả code blocks được đóng đúng cách (không bị truncate)
