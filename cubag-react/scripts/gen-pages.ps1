$pagesDir = "$PSScriptRoot\..\src\pages"
New-Item -ItemType Directory -Force -Path $pagesDir | Out-Null

$pages = @{
  "Landing" = "Landing"
  "Login" = "Login"
  "Register" = "Register"
  "ForgotPassword" = "Forgot Password"
  "Dashboard" = "Dashboard"
  "Profile" = "My Profile"
  "Announcements" = "Announcements"
  "Events" = "Events"
  "Networking" = "Networking"
  "Payments" = "Payments"
  "Tasks" = "Tasks & Compliance"
  "Surveys" = "Surveys & Elections"
  "LicenseRenewal" = "License Renewal"
  "LiveData" = "Live Logistics Data"
  "Engagement" = "Contact & Support"
  "PublicServices" = "Public Services"
}

foreach ($name in $pages.Keys) {
  $title = $pages[$name]
  $file = "$pagesDir\$name.jsx"
  if (-not (Test-Path $file)) {
    $content = "export default function $name() { return <div style={{padding:'40px'}}><h2>$title</h2><p>Coming soon.</p></div> }"
    Set-Content -Path $file -Value $content -Encoding UTF8
    Write-Host "Created $name.jsx"
  } else {
    Write-Host "Skipped $name.jsx (exists)"
  }
}
Write-Host "Done."
