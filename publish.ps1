# ============================================================
# [HTML Report Hub] 보고서 자동 배포 PowerShell 스크립트
# ============================================================
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"

try {
    $repoDir = $PSScriptRoot
    if (-not $repoDir) { $repoDir = (Get-Location).Path }
    Set-Location $repoDir

    $baseUrl = "https://ooklllo.github.io/html_reports"
    $indexUrl = "$baseUrl/index.html"

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Write-Host "   📊 [HTML Report Hub] 보고서 자동 배포 시스템" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor DarkCyan
    Write-Host ""

    Write-Host "[1/6] Git 환경 및 사용자 계정 정보 확인..." -ForegroundColor Cyan
    # 사용자 계정 규칙 준수 (moabattle / moabattle@gmail.com)
    git config user.name "moabattle"
    git config user.email "moabattle@gmail.com"

    # Git 저장소 검사
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "현재 폴더는 Git 저장소가 아닙니다."
    }

    Write-Host "[2/6] HTML 보고서 파일 탐색 및 신규 파일 감지..." -ForegroundColor Cyan
    $htmlFiles = Get-ChildItem -Path $repoDir -Filter "*.html" | Where-Object { $_.Name -ne "index.html" }

    if (-not $htmlFiles -or $htmlFiles.Count -eq 0) {
        Write-Host "   - 현재 폴더에 배포할 HTML 보고서 파일이 없습니다." -ForegroundColor Yellow
        Write-Host "   - index.html 페이지를 브라우저로 엽니다."
        Start-Process $indexUrl
        Write-Host ""
        Write-Host "5초 후 창이 자동으로 종료됩니다..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 5
        [System.Environment]::Exit(0)
    }

    # Git 상태 확인하여 신규/수정/삭제된 HTML 파일 목록 식별
    $gitStatusLines = git status --porcelain
    $uncommittedFiles = @()
    $deletedFiles = @()
    foreach ($line in $gitStatusLines) {
        if ($line.Length -ge 4) {
            $status = $line.Substring(0, 2)
            $filePath = $line.Substring(3).Trim().Replace('"', '')
            $fileName = [System.IO.Path]::GetFileName($filePath)
            if ($fileName.EndsWith(".html") -and $fileName -ne "index.html") {
                if ($status -match 'D') {
                    $deletedFiles += $fileName
                } else {
                    $uncommittedFiles += $fileName
                }
            }
        }
    }

    $newReportUrls = @()
    if ($uncommittedFiles.Count -gt 0) {
        Write-Host "   -> 발견된 신규/수정 보고서 ($($uncommittedFiles.Count)개):" -ForegroundColor Green
        foreach ($f in $uncommittedFiles) {
            Write-Host "      * $f" -ForegroundColor Green
            $newReportUrls += "$baseUrl/$f"
        }
    }
    if ($deletedFiles.Count -gt 0) {
        Write-Host "   -> 삭제 감지된 보고서 ($($deletedFiles.Count)개):" -ForegroundColor Red
        foreach ($f in $deletedFiles) {
            Write-Host "      * $f (목록 및 원격 저장소에서 제거됨)" -ForegroundColor Red
        }
    }
    if ($uncommittedFiles.Count -eq 0 -and $deletedFiles.Count -eq 0) {
        Write-Host "   -> 새로 추가되거나 삭제된 보고서가 없습니다. (전체 목록 동기화 진행)" -ForegroundColor Gray
    }

    Write-Host "[3/6] index.html 보고서 목록 갱신 (최신순 정렬)..." -ForegroundColor Cyan

    # 최신 수정 시간(LastWriteTime) 내림차순 정렬
    $sortedFiles = $htmlFiles | Sort-Object LastWriteTime -Descending

    $cardsHtml = ""
    $isFirst = $true

    foreach ($file in $sortedFiles) {
        # HTML 파일에서 <title> 추출
        $title = $file.BaseName
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            if ($content -match '<title>(.*?)</title>') {
                $matchedTitle = $matches[1].Trim()
                if ($matchedTitle) { $title = $matchedTitle }
            }
        } catch {}

        $dateStr = $file.LastWriteTime.ToString("yyyy-MM-dd")
        $fileSizeKb = [Math]::Round($file.Length / 1KB, 1)

        $latestClass = if ($isFirst) { " is-latest" } else { "" }
        $badgeHtml = if ($isFirst) { '<span class="badge-new">NEW</span>' } else { '' }

        $card = '      <a href="' + $file.Name + '" class="report-card' + $latestClass + '">' + "`n"
        $card += '        <div class="card-left">' + "`n"
        $card += '          <div class="card-meta">' + "`n"
        if ($badgeHtml) { $card += '            ' + $badgeHtml + "`n" }
        $card += '            <span class="card-date">' + $dateStr + '</span>' + "`n"
        $card += '            <span class="card-filename">' + $file.Name + ' (' + $fileSizeKb + 'KB)</span>' + "`n"
        $card += '          </div>' + "`n"
        $card += '          <div class="card-title">' + $title + '</div>' + "`n"
        $card += '        </div>' + "`n"
        $card += '        <div class="card-right">' + "`n"
        $card += '          <span class="btn-open">보고서 열기 →</span>' + "`n"
        $card += '        </div>' + "`n"
        $card += '      </a>' + "`n"

        $cardsHtml += $card
        $isFirst = $false
    }

    # index.html 파일 읽기 및 영역 치환
    $indexPath = Join-Path $repoDir "index.html"
    if (Test-Path $indexPath) {
        $indexContent = Get-Content -Path $indexPath -Raw -Encoding UTF8
        $nowDate = (Get-Date).ToString("yyyy-MM-dd")
        $totalCount = $sortedFiles.Count

        # 통계 영역 갱신
        $indexContent = [regex]::Replace($indexContent, 'id="total-reports">\d+<', "id=`"total-reports`">$totalCount<")
        $indexContent = [regex]::Replace($indexContent, 'id="last-updated">[^<]+<', "id=`"last-updated`">$nowDate<")

        # 목록 영역 치환
        $pattern = '(?s)<!-- REPORT_LIST_START -->.*?<!-- REPORT_LIST_END -->'
        $replacement = "<!-- REPORT_LIST_START -->`n    <div class=`"report-list`" id=`"report-list`">`n$cardsHtml    </div>`n    <!-- REPORT_LIST_END -->"
        $indexContent = [regex]::Replace($indexContent, $pattern, $replacement)

        [System.IO.File]::WriteAllText($indexPath, $indexContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "   - index.html 업데이트 완료 (총 $($totalCount)개 보고서 등록)" -ForegroundColor Green
    }

    Write-Host "[4/6] Git 커밋 및 GitHub 원격 푸시..." -ForegroundColor Cyan
    git add .
    if ($LASTEXITCODE -ne 0) { throw "git add 실패" }

    # 커밋 메시지 구성
    $nowStr = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $actions = @()
    if ($uncommittedFiles.Count -gt 0) {
        $actions += "Add/Update: " + ($uncommittedFiles -join ", ")
    }
    if ($deletedFiles.Count -gt 0) {
        $actions += "Delete: " + ($deletedFiles -join ", ")
    }

    if ($actions.Count -gt 0) {
        $commitMsg = ($actions -join " / ") + " ($nowStr)"
    } else {
        $commitMsg = "Refresh report index ($nowStr)"
    }

    # 변경 사항이 있는 경우 커밋
    $statusCheck = git status --porcelain
    if ($statusCheck) {
        git commit -m "$commitMsg"
        if ($LASTEXITCODE -ne 0) { throw "git commit 실패" }
        Write-Host "   - 커밋 생성 완료: $commitMsg" -ForegroundColor Green
    } else {
        Write-Host "   - 변경 사항이 없어 커밋 생성을 건너뜁니다." -ForegroundColor Gray
    }

    Write-Host "   - GitHub 푸시 진행 중 (origin main)..." -ForegroundColor Yellow
    git push origin main
    if ($LASTEXITCODE -ne 0) { throw "GitHub 푸시(git push)에 실패했습니다. 권한 또는 네트워크를 확인하세요." }
    Write-Host "   - GitHub 푸시 완료!" -ForegroundColor Green

    Write-Host "[5/6] 공유 링크 클립보드 복사..." -ForegroundColor Cyan
    $clipboardText = ""
    if ($newReportUrls.Count -gt 0) {
        # 새 보고서가 여러 개일 경우 줄바꿈으로 모두 합쳐서 복사
        $clipboardText = $newReportUrls -join "`r`n"
        Write-Host "   - 새 보고서 링크 ($($newReportUrls.Count)개)가 클립보드에 복사되었습니다! (Ctrl+V 로 바로 붙여넣기 가능)" -ForegroundColor Green
        foreach ($u in $newReportUrls) {
            Write-Host "     * $u" -ForegroundColor White
        }
    } else {
        $clipboardText = $indexUrl
        Write-Host "   - index.html 주소가 클립보드에 복사되었습니다! (Ctrl+V 로 공유 가능)" -ForegroundColor Green
        Write-Host "     * $indexUrl" -ForegroundColor White
    }

    # 클립보드 복사
    try {
        Set-Clipboard -Value $clipboardText
    } catch {
        $clipboardText | clip.exe
    }

    Write-Host "[6/6] 크롬 브라우저 실행..." -ForegroundColor Cyan
    try {
        Start-Process "chrome.exe" -ArgumentList $indexUrl -ErrorAction Stop
        Write-Host "   - 크롬 브라우저로 $indexUrl 을 열었습니다." -ForegroundColor Green
    } catch {
        Start-Process $indexUrl
        Write-Host "   - 기본 브라우저로 $indexUrl 을 열었습니다." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "   [완료] 배포가 성공적으로 완료되었습니다!" -ForegroundColor Green
    Write-Host "   5초 후 창이 자동으로 종료됩니다... (아무 키나 누르면 즉시 종료)" -ForegroundColor Gray
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host ""

    # 5초 카운트다운
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "`r   [자동 종료까지 $i초...] " -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
    }
    Write-Host ""

    [System.Environment]::Exit(0)

} catch {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host " [ERROR] 배포 도중 오류가 발생했습니다!" -ForegroundColor Red
    Write-Host " 내용: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "문제가 발생하여 창을 유지합니다. 확인 후 아무 키나 누르시면 창이 닫힙니다..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    [System.Environment]::Exit(1)
}
