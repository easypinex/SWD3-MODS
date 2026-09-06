[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [Parameter(Mandatory)][string]$StatePath,
    [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
$plan = Get-Content -LiteralPath $PlanPath -Raw | ConvertFrom-Json
$state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
if ($plan.Schema -notin @(2,3) -or $state.Schema -ne 2) { throw 'Expected release plan schema 2/3 and state schema 2.' }
$target = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $target) { throw 'Use a new report output path.' }
function Escape($value) { [Net.WebUtility]::HtmlEncode([string]$value) }
$matchesReviewed = $null -ne $state.ReviewedPlan
if ($matchesReviewed) {
    foreach ($property in $plan.PSObject.Properties) {
        if (($property.Value | ConvertTo-Json -Depth 10 -Compress) -cne ($state.ReviewedPlan.($property.Name) | ConvertTo-Json -Depth 10 -Compress)) { $matchesReviewed = $false }
    }
}
$verified = $state.Phase -eq 'verified' -and $matchesReviewed
$status = if ($verified) { '已驗證更新完成' } elseif ($state.Phase -eq 'reviewed') { '已準備，尚未發佈' } else { '尚未驗證完成' }
$badge = if ($verified) { 'ok' } else { 'pending' }
$remote = if ($state.After) { $state.After } else { $state.Before }
$files = if ($state.AfterFiles) { @($state.AfterFiles) } else { @($state.BeforeFiles) }
$file = if ($files.Count -eq 1) { $files[0] } else { $null }
$pairs = @(
    @('標題', $plan.Title, $remote.Title),
    @('版本', $plan.Version, $remote.Version),
    @('下載檔名', $plan.FileName, $file.FileName),
    @('檔案大小', [string]$plan.ContentSize, [string]$file.Size),
    @('封包內實際版本', $plan.Version, $file.Package.Version),
    @('SHA-256', $plan.ContentSha256, $file.Sha256)
)
if ($plan.Schema -ge 3 -and $plan.Language -ne 'english') {
    $default = if ($state.AfterDefault) { $state.AfterDefault } else { $state.BeforeDefault }
    $pairs += ,@('預設語言標題', $plan.Title, $default.Title)
    $pairs += ,@('預設語言說明', $plan.Description, $default.Description)
}
$rows = foreach ($pair in $pairs) {
    $matches = [string]$pair[1] -ceq [string]$pair[2]
    $label = if ($matches) { '一致' } else { '有差異' }
    '<tr><th>' + (Escape $pair[0]) + '</th><td>' + (Escape $pair[1]) + '</td><td>' + (Escape $pair[2]) + '</td><td>' + $label + '</td></tr>'
}
$descriptionMatches = [string]$plan.Description -ceq [string]$remote.Description
$descriptionLabel = if ($descriptionMatches) { '一致' } else { '有差異' }
$timeText = if ($state.VerifiedAt) { '驗證時間：' + (Escape $state.VerifiedAt) } else { '此報告尚無成功驗證時間。' }
$html = @"
<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MOD Studio · 發佈與更新核對</title>
<style>
:root{font-family:"Segoe UI","Microsoft JhengHei",sans-serif;color:#24333f;background:#f1f4f6}*{box-sizing:border-box}body{margin:0;padding:40px 24px}main{max-width:1120px;margin:auto}header{border-top:4px solid #167f70;padding:26px 0}h1{font-size:32px;margin:8px 0 14px;letter-spacing:-1px}h2{font-size:20px}p{line-height:1.7}.eyebrow{color:#53716d;font-size:13px;letter-spacing:2px}.status{display:inline-block;padding:7px 13px;border-radius:20px;font-weight:600}.ok{background:#d9f0e8;color:#13694f}.pending{background:#fff0ce;color:#80510d}.meta{display:flex;gap:24px;flex-wrap:wrap;color:#5c6a73;font-size:14px}section{background:white;padding:24px;border-radius:12px;margin:20px 0;border:1px solid #e0e7e9}table{border-collapse:collapse;width:100%;table-layout:fixed;font-size:14px}th,td{text-align:left;padding:15px 12px;border-bottom:1px solid #e4e9ec;overflow-wrap:anywhere;vertical-align:top}thead{background:#f5f8f9}th:first-child{width:18%}th:last-child{width:9%}.columns{display:grid;grid-template-columns:1fr 1fr;gap:20px}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:15px/1.8 "Segoe UI","Microsoft JhengHei",sans-serif;background:#f6f8f9;padding:18px;border-radius:8px;margin:0}.note{font-size:13px;color:#66777e}a{color:#167f70}.error{color:#9c392f}@media(max-width:720px){body{padding:20px 12px}.columns{grid-template-columns:1fr}section{padding:14px}th,td{padding:10px 5px}h1{font-size:26px}}
</style><main>
<header><div class="eyebrow">SWD3 MOD STUDIO / STEAM 原型 0.2</div><h1>發佈與更新核對</h1><span class="status $badge">$status</span>
<p>$(Escape $plan.Title)</p><div class="meta"><span>作品 ID：$(Escape $state.WorkshopId)</span><span>版本：$(Escape $plan.Version)</span><span>語言：$(Escape $plan.Language)</span></div></header>
<section><h2>標題、版本與下載檔案</h2><div style="overflow-x:auto"><table><thead><tr><th>核對項目</th><th>本次預期</th><th>Steam 實際查回／下載</th><th>比對</th></tr></thead><tbody>$($rows -join "`n")</tbody></table></div>
<p class="note">實際下載檔案數：$($files.Count)。封包內版本由下載後的 .ssmod 讀取；完整檔案的 SHA-256 用於確認內容相同。</p></section>
<section><h2>內容說明 · $descriptionLabel</h2><div class="columns"><div><p>本次預期</p><pre>$(Escape $plan.Description)</pre></div><div><p>Steam 實際查回</p><pre>$(Escape $remote.Description)</pre></div></div></section>
<section><h2>本次更新說明</h2><pre>$(Escape $plan.ChangeNote)</pre><p class="note">更新說明已隨提交送出；目前原型的逐字回查涵蓋作品標題與內容說明，未回查 Steam 歷史更新說明。</p>
<p class="error">$(Escape $state.LastError)</p><p>$timeText</p></section>
<p class="note">此為該次操作的本機紀錄，非即時頁面。再次查詢請使用工具的「詳情／檔案／驗證」指令。正式遊戲內功能另需 MOD 實機驗收。</p>
</main></html>
"@
New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
[IO.File]::WriteAllText($target, $html, [Text.UTF8Encoding]::new($false))
Write-Output "Report: $target"
