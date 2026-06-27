# Slices weapon icons from darkest_dungeon_weapons_sheet.png (keep in sync with weapon_sheet_definitions.gd)
param(
    [string]$ProjectRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "")
)

Add-Type -AssemblyName System.Drawing

$sheetPath = Join-Path $ProjectRoot "assets\tilesets\source\darkest_dungeon_weapons_sheet.png"
$entries = @(
    @{ item_id = "scrap_greatsword"; icon = "assets\items\weapons\melee\scrap_greatsword.png"; x = 4; y = 2; w = 86; h = 94 },
    @{ item_id = "machete"; icon = "assets\items\weapons\melee\machete.png"; x = 176; y = 184; w = 52; h = 44 },
    @{ item_id = "rusty_knife"; icon = "assets\items\weapons\melee\rusty_knife.png"; x = 36; y = 186; w = 44; h = 72 },
    @{ item_id = "fire_axe"; icon = "assets\items\weapons\melee\fire_axe.png"; x = 6; y = 266; w = 58; h = 56 },
    @{ item_id = "war_axe"; icon = "assets\items\weapons\melee\war_axe.png"; x = 878; y = 252; w = 132; h = 122 },
    @{ item_id = "old_revolver"; icon = "assets\items\weapons\ranged\old_revolver.png"; x = 84; y = 542; w = 102; h = 46 },
    @{ item_id = "service_pistol"; icon = "assets\items\weapons\ranged\service_pistol.png"; x = 4; y = 548; w = 76; h = 42 },
    @{ item_id = "hunting_rifle"; icon = "assets\items\weapons\ranged\hunting_rifle.png"; x = 188; y = 542; w = 110; h = 50 },
    @{ item_id = "pump_shotgun"; icon = "assets\items\weapons\ranged\pump_shotgun.png"; x = 418; y = 538; w = 108; h = 54 },
    @{ item_id = "compact_smg"; icon = "assets\items\weapons\ranged\compact_smg.png"; x = 530; y = 536; w = 105; h = 56 },
    @{ item_id = "scoped_sniper"; icon = "assets\items\weapons\ranged\scoped_sniper.png"; x = 638; y = 534; w = 112; h = 58 },
    @{ item_id = "heavy_crossbow"; icon = "assets\items\weapons\ranged\heavy_crossbow.png"; x = 908; y = 4; w = 98; h = 204 },
    @{ item_id = "frag_grenade"; icon = "assets\items\weapons\ranged\frag_grenade.png"; x = 888; y = 572; w = 62; h = 82 },
    @{ item_id = "dd_skull_dagger"; icon = "assets\items\weapons\melee\dd_skull_dagger.png"; x = 286; y = 26; w = 54; h = 68 },
    @{ item_id = "dd_shortsword"; icon = "assets\items\weapons\melee\dd_shortsword.png"; x = 188; y = 0; w = 68; h = 95 },
    @{ item_id = "dd_throw_knife"; icon = "assets\items\weapons\melee\dd_throw_knife.png"; x = 254; y = 38; w = 32; h = 52 },
    @{ item_id = "dd_ritual_dagger"; icon = "assets\items\weapons\melee\dd_ritual_dagger.png"; x = 418; y = 100; w = 38; h = 70 },
    @{ item_id = "dd_war_pick"; icon = "assets\items\weapons\melee\dd_war_pick.png"; x = 128; y = 274; w = 52; h = 50 },
    @{ item_id = "dd_hatchet"; icon = "assets\items\weapons\melee\dd_hatchet.png"; x = 70; y = 270; w = 56; h = 54 },
    @{ item_id = "dd_halberd"; icon = "assets\items\weapons\melee\dd_halberd.png"; x = 198; y = 326; w = 168; h = 62 },
    @{ item_id = "dd_war_pike"; icon = "assets\items\weapons\melee\dd_war_pike.png"; x = 188; y = 404; w = 228; h = 62 },
    @{ item_id = "dd_morning_star"; icon = "assets\items\weapons\melee\dd_morning_star.png"; x = 932; y = 412; w = 78; h = 100 },
    @{ item_id = "dd_hunter_bow"; icon = "assets\items\weapons\ranged\dd_hunter_bow.png"; x = 862; y = 6; w = 46; h = 200 },
    @{ item_id = "dd_longbow"; icon = "assets\items\weapons\ranged\dd_longbow.png"; x = 908; y = 4; w = 98; h = 204 },
    @{ item_id = "dd_scrap_carbine"; icon = "assets\items\weapons\ranged\dd_scrap_carbine.png"; x = 302; y = 540; w = 112; h = 52 },
    @{ item_id = "dd_combat_rifle"; icon = "assets\items\weapons\ranged\dd_combat_rifle.png"; x = 752; y = 532; w = 108; h = 60 },
    @{ item_id = "dd_stick_grenade"; icon = "assets\items\weapons\ranged\dd_stick_grenade.png"; x = 948; y = 568; w = 66; h = 86 },
    @{ item_id = "dd_mine_ball"; icon = "assets\items\weapons\ranged\dd_mine_ball.png"; x = 844; y = 606; w = 50; h = 54 }
)

function Key-BlackBackground([System.Drawing.Bitmap]$bitmap) {
    for ($y = 0; $y -lt $bitmap.Height; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.R -le 22 -and $pixel.G -le 22 -and $pixel.B -le 22) {
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            }
        }
    }
}

function Save-FittedIcon([System.Drawing.Bitmap]$source, [System.Drawing.Rectangle]$rect, [string]$outPath) {
    $crop = New-Object System.Drawing.Bitmap $rect.Width, $rect.Height
    $graphics = [System.Drawing.Graphics]::FromImage($crop)
    $graphics.DrawImage($source, 0, 0, $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    Key-BlackBackground $crop

    $iconSize = 128
    $padding = 12
    $maxDim = [Math]::Max($crop.Width, $crop.Height)
    $scale = ($iconSize - $padding) / [double]$maxDim
    $drawW = [Math]::Max(1, [int][Math]::Round($crop.Width * $scale))
    $drawH = [Math]::Max(1, [int][Math]::Round($crop.Height * $scale))
    $icon = New-Object System.Drawing.Bitmap $iconSize, $iconSize
    $g = [System.Drawing.Graphics]::FromImage($icon)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $offsetX = [int](($iconSize - $drawW) / 2)
    $offsetY = [int](($iconSize - $drawH) / 2)
    $g.DrawImage($crop, $offsetX, $offsetY, $drawW, $drawH)
    $g.Dispose()
    $crop.Dispose()

    $dir = Split-Path -Parent $outPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $icon.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $icon.Dispose()
}

if (-not (Test-Path $sheetPath)) {
    Write-Error "Sheet not found: $sheetPath"
    exit 1
}

$sheet = [System.Drawing.Bitmap]::FromFile($sheetPath)
$saved = 0
foreach ($entry in $entries) {
    $out = Join-Path $ProjectRoot $entry.icon
    $rect = New-Object System.Drawing.Rectangle $entry.x, $entry.y, $entry.w, $entry.h
    Save-FittedIcon $sheet $rect $out
    $saved++
    Write-Output "Saved $($entry.item_id)"
}
$sheet.Dispose()
Write-Output "Done. Saved $saved icons."
