# Ensure the script runs in the directory provided, or defaults to the current location
param (
    [string]$TargetDir = "C:\Users\Compat\portfolio\my-portfolio"
)

# 1. Open/Change to the target directory
if (Test-Path $TargetDir) {
    Set-Location $TargetDir
    Clear-Host
    Write-Host "Current Directory: $(Get-Location)" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
} else {
    Write-Error "The specified directory does not exist: $TargetDir"
    Exit
}

# 2. Check if it's a valid Git repository
if (-not (Test-Path ".git")) {
    Write-Warning "This directory is not a Git repository! Initializing git..."
    git init
}

# 3. Fetch and list all files and folders (Force fresh look)
$items = Get-ChildItem -Exclude ".git", ".gitignore"
if ($items.Count -eq 0) {
    Write-Host "No files or folders found to process." -ForegroundColor Yellow
    Exit
}

Write-Host "Select items to IGNORE by entering their serial numbers." -ForegroundColor Green
Write-Host "Available Files & Folders:" -ForegroundColor Yellow
Write-Host "--------------------------------------------------" -ForegroundColor Gray

# Display items with a serial number (1-indexed)
for ($i = 0; $i -lt $items.Count; $i++) {
    $itemType = if ($items[$i].PSIsContainer) { "[Folder]" } else { "[File]" }
    Write-Host ("[{0}] {1,-8} {2}" -f ($i + 1), $itemType, $items[$i].Name)
}

Write-Host "--------------------------------------------------" -ForegroundColor Gray

# 4. Input field for items to ignore
$inputString = Read-Host "Enter serial numbers to IGNORE (comma-separated, e.g., 1, 6, 8, 3) or press Enter to push all"

# 5. Process the input and update .gitignore
if (-not [string]::IsNullOrWhiteSpace($inputString)) {
    # Split input by commas and clean up spaces
    $indices = $inputString.Split(',') | ForEach-Object { $_.Trim() }
    
    Write-Host "`nUpdating .gitignore..." -ForegroundColor Cyan
    
    $index = 0
    
    foreach ($indexStr in $indices) {
        if ([int]::TryParse($indexStr, [ref]$index)) {
            if ($index -ge 1 -and $index -le $items.Count) {
                $ignoredItem = $items[$index - 1].Name
                
                # Append to .gitignore if it's not already there
                if (Test-Path ".gitignore") {
                    $existing = Get-Content ".gitignore"
                    if ($existing -notcontains $ignoredItem) {
                        Add-Content -Path ".gitignore" -Value $ignoredItem
                        Write-Host "Added to ignore: $ignoredItem" -ForegroundColor Yellow
                    }
                } else {
                    Out-File -FilePath ".gitignore" -InputObject $ignoredItem -Encoding utf8
                    Write-Host "Created .gitignore and added: $ignoredItem" -ForegroundColor Yellow
                }
                
                # CRITICAL: Forcefully remove from cache if it was previously tracked
                git rm -r --cached $ignoredItem 2>$null
            } else {
                Write-Warning "Invalid selection skipped: $indexStr"
            }
        }
    }
} else {
    Write-Host "`nNo files selected to ignore. Moving forward with all files." -ForegroundColor Gray
}

# 6. Git Push Sequence (The Fix)
Write-Host "`nStaging files for Git..." -ForegroundColor Cyan
git add --all  # Using --all ensures untracked/modified/deleted adjustments are fully captured

# Prompt user for a custom commit message to make it valid and explicit
Write-Host ""
$customMsg = Read-Host "Enter your Git commit message (or press Enter for default auto-message)"
if ([string]::IsNullOrWhiteSpace($customMsg)) {
    $commitMessage = "Git Maintenance Auto-Push: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
} else {
    $commitMessage = $customMsg
}

# Run the explicit commit
Write-Host "`nCommitting changes..." -ForegroundColor Cyan
git commit -m "$commitMessage"

# Push handling for remote syncing
Write-Host "`nPushing to GitHub remote repository..." -ForegroundColor Cyan

# Check the current local branch name (e.g., master)
$currentBranch = (git branch --show-current).Trim()

# Force push to set upstream tracking explicitly
git push --set-upstream origin $currentBranch

Write-Host "`nGit maintenance task completed successfully!" -ForegroundColor Green