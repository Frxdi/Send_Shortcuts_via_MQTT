# Global variables for state tracking
$script:red = 0
$script:orange = 0
$script:green = 0
$script:blue = 0
$script:white = 0
$script:buzzerc = 0
$script:buzzerp = 0

# Color cycling functions
function Red {
    $script:red = if ($script:red -eq 0) { 1 } elseif ($script:red -eq 1) { 2 } else { 0 }
    Write-Host "r=$script:red"
}

function Orange {
    $script:orange = if ($script:orange -eq 0) { 1 } elseif ($script:orange -eq 1) { 2 } else { 0 }
    Write-Host "o=$script:orange"
}

function Green {
    $script:green = if ($script:green -eq 0) { 1 } elseif ($script:green -eq 1) { 2 } else { 0 }
    Write-Host "g=$script:green"
}

function Blue {
    $script:blue = if ($script:blue -eq 0) { 1 } elseif ($script:blue -eq 1) { 2 } else { 0 }
    Write-Host "b=$script:blue"
}

function White {
    $script:white = if ($script:white -eq 0) { 1 } elseif ($script:white -eq 1) { 2 } else { 0 }
    Write-Host "w=$script:white"
}

function Buzzerc {
    $script:buzzerc = if ($script:buzzerc -eq 0) { 1 } else { 0 }
    Write-Host "bc=$script:buzzerc"
}

function Buzzerp {
    $script:buzzerp = if ($script:buzzerp -eq 0) { 1 } else { 0 }
    Write-Host "bp=$script:buzzerp"
}

# Windows API to check async key state
$GetAsyncKeyStateSignature = @"
[DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);
"@

Add-Type -MemberDefinition $GetAsyncKeyStateSignature -Name KeyState -Namespace Win32

# Virtual key codes
$VK_CONTROL = 0x11
$VK_MENU = 0x12      # Alt key
$VK_1 = 0x31
$VK_2 = 0x32
$VK_3 = 0x33
$VK_4 = 0x34
$VK_5 = 0x35
$VK_6 = 0x36
$VK_7 = 0x37

# Function to check if a key is pressed
function Test-IsKeyPressed {
    param([int]$vKey)
    $state = [Win32.KeyState]::GetAsyncKeyState($vKey)
    return ($state -band 0x8000) -ne 0
}

# Track previous states to prevent repeated triggers
$script:previousStates = @{}

Write-Host "Hotkey listener started. Press Ctrl+Alt+1-7 to toggle states."
Write-Host "Press Ctrl+C to exit."
Write-Host ""
Write-Host "Available hotkeys:"
Write-Host "  Ctrl+Alt+1 -> Red"
Write-Host "  Ctrl+Alt+2 -> Orange"
Write-Host "  Ctrl+Alt+3 -> Green"
Write-Host "  Ctrl+Alt+4 -> Blue"
Write-Host "  Ctrl+Alt+5 -> White"
Write-Host "  Ctrl+Alt+6 -> Buzzer (Correct)"
Write-Host "  Ctrl+Alt+7 -> Buzzer (Problem)"
Write-Host ""

# Hotkey configuration
$hotkeyConfig = @{
    $VK_1 = @{ func = { Red }; name = "Red" }
    $VK_2 = @{ func = { Orange }; name = "Orange" }
    $VK_3 = @{ func = { Green }; name = "Green" }
    $VK_4 = @{ func = { Blue }; name = "Blue" }
    $VK_5 = @{ func = { White }; name = "White" }
    $VK_6 = @{ func = { Buzzerc }; name = "Buzzer Correct" }
    $VK_7 = @{ func = { Buzzerp }; name = "Buzzer Problem" }
}

try {
    while ($true) {
        $ctrlPressed = Test-IsKeyPressed $VK_CONTROL
        $altPressed = Test-IsKeyPressed $VK_MENU
        $ctrlAltPressed = $ctrlPressed -and $altPressed
        
        # Check each number key
        foreach ($vk in $hotkeyConfig.Keys) {
            $isPressed = Test-IsKeyPressed $vk
            
            if (-not $script:previousStates.ContainsKey($vk)) {
                $script:previousStates[$vk] = $false
            }
            
            # Trigger on key press (transition from released to pressed)
            if ($isPressed -and -not $script:previousStates[$vk] -and $ctrlAltPressed) {
                $script:previousStates[$vk] = $true
                & $hotkeyConfig[$vk].func
                Write-Host "Triggered: $($hotkeyConfig[$vk].name)" -ForegroundColor Gray
            }
            elseif (-not $isPressed) {
                $script:previousStates[$vk] = $false
            }
        }
        
        
    }
}
catch {
    Write-Host "Error: $_"
}
finally {
    Write-Host "Hotkey listener stopped."
}
