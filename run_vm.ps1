# ========================================================
# ZUNRDP VM AGENT SCRIPT
# ========================================================

# 1. CẤU HÌNH (THAY ĐỔI THEO REPLIT CỦA BẠN)
$serverUrl = "https://nodejs-1--rdp26082007.replit.app"
$user = "ADMINZUN"
$pass = "ZunRDP@123456"

# 2. KHỞI TẠO ID MÁY NGẪU NHIÊN (Ví dụ: ZUN-A1B2C3)
$charSet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
$vmID = "ZUN-" + (-join (1..6 | % { $charSet[(Get-Random -Maximum $charSet.Length)] }))

Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host ">>> KHOI DONG MAY AO: $vmID" -ForegroundColor Cyan
Write-Host ">>> KET NOI DEN: $serverUrl" -ForegroundColor Cyan
Write-Host "------------------------------------------" -ForegroundColor Cyan

# 3. VÒNG LẶP CHÍNH (MỖI 5 GIÂY)
while($true) {
    try {
        # A. Lấy địa chỉ IP (Ưu tiên Tailscale)
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Tailscale*"}).IPAddress
        if (!$ip) { 
            # Nếu chưa có Tailscale, lấy IP mạng chính
            $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Dhcp"}).IPAddress[0]
        }
        if (!$ip) { $ip = "127.0.0.1" }

        # B. Tính toán Uptime (Thời gian đã chạy)
        $osObj = Get-CimInstance Win32_OperatingSystem
        $uptimeSpan = (Get-Date) - $osObj.LastBootUpTime
        $uptimeStr = "{0:00}h {1:00}m {2:00}s" -f $uptimeSpan.Hours, $uptimeSpan.Minutes, $uptimeSpan.Seconds

        # C. Chuẩn bị dữ liệu gửi đi (JSON)
        $payload = @{
            id     = $vmID
            os     = "Windows"
            ip     = $ip
            user   = $user
            pass   = $pass
            status = "running"
            uptime = $uptimeStr
        } | ConvertTo-Json -Compress

        # D. Gửi báo cáo trạng thái (Heartbeat)
        $headers = @{"Content-Type" = "application/json"}
        Invoke-RestMethod -Uri "$serverUrl/api/update" -Method Post -Body $payload -Headers $headers -TimeoutSec 5

        # E. Kiểm tra xem có lệnh nào từ Dashboard không
        $checkCmd = Invoke-RestMethod -Uri "$serverUrl/api/command/$vmID" -Method Get -TimeoutSec 5
        
        if ($checkCmd.command) {
            $cmd = $checkCmd.command.ToLower()
            Write-Host "!!! NHAN LENH TU DASHBOARD: $cmd !!!" -ForegroundColor Red
            
            if ($cmd -eq "kill") {
                Write-Host "Dang dung may theo yeu cau..." -ForegroundColor Yellow
                # Thoát script với mã lỗi để GitHub Action dừng hẳn job
                exit 1 
            }
            elseif ($cmd -eq "restart") {
                Write-Host "Dang khoi dong lai he thong..." -ForegroundColor Yellow
                Restart-Computer -Force
            }
            elseif ($cmd -eq "pause") {
                Write-Host "Tam dung trang thai 30s..." -ForegroundColor Yellow
                Start-Sleep -Seconds 30
            }
        }
    }
    catch {
        Write-Host "[!] Loi ket noi server: $($_.Exception.Message)" -ForegroundColor Gray
    }

    # Đợi 5 giây trước khi lặp lại
    Start-Sleep -Seconds 5
}
