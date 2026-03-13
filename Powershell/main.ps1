# Load .env configuration
function Load-EnvFile {
    param([string]$envPath)
    
    if (-not (Test-Path $envPath)) {
        Write-Host "Error: .env file not found at $envPath" -ForegroundColor Red
        exit 1
    }
    
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)\s*=\s*(.+)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

# Load environment variables from .env file
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFilePath = Join-Path $scriptDirectory ".env"
Load-EnvFile $envFilePath

# Get MQTT configuration from environment
$script:BROKER = [Environment]::GetEnvironmentVariable('BROKER', 'Process')
$script:PORT = [Environment]::GetEnvironmentVariable('PORT', 'Process')

# Validate MQTT configuration
if (-not $script:BROKER -or -not $script:PORT) {
    Write-Host "Error: BROKER or PORT not defined in .env file" -ForegroundColor Red
    exit 1
}

Write-Host "MQTT Configuration loaded: Broker=$script:BROKER, Port=$script:PORT" -ForegroundColor Green

# Global variables for state tracking
$script:red = 0
$script:orange = 0
$script:green = 0
$script:blue = 0
$script:white = 0
$script:buzzerc = 0
$script:buzzerp = 0

# MQTT client connection
$script:mqttClient = $null
$script:mqttStream = $null
$script:mqttConnected = $false

# MQTT Functions
function Initialize-MQTT {
    try {
        $script:mqttClient = New-Object System.Net.Sockets.TcpClient
        $script:mqttClient.Connect($script:BROKER, [int]$script:PORT)
        $stream = $script:mqttClient.GetStream()
        $script:mqttStream = $stream

        # Build MQTT CONNECT packet (protocol: MQTT 3.1.1)
        $clientId = "PS_Client"
        $clientIdBytes = [System.Text.Encoding]::UTF8.GetBytes($clientId)

        $payload = @(
            0x00, $clientIdBytes.Length  # Client ID length (2 bytes)
        ) + $clientIdBytes

        $variableHeader = @(
            0x00, 0x04,                  # Protocol name length
            0x4D, 0x51, 0x54, 0x54,      # "MQTT"
            0x04,                        # Protocol level (3.1.1)
            0x02,                        # Connect flags (Clean session)
            0x00, 0x3C                   # Keep-alive: 60s
        )

        $remainingLength = $variableHeader.Length + $payload.Length
        $fixedHeader = @(0x10, $remainingLength)  # CONNECT packet type

        $packet = [byte[]]($fixedHeader + $variableHeader + $payload)
        $stream.Write($packet, 0, $packet.Length)
        $stream.Flush()

        # Read CONNACK (should be 4 bytes: 0x20 0x02 0x00 0x00)
        Start-Sleep -Milliseconds 500
        $response = New-Object byte[] 4
        $stream.Read($response, 0, 4) | Out-Null

        if ($response[0] -eq 0x20 -and $response[3] -eq 0x00) {
            $script:mqttConnected = $true
            Write-Host "Connected to MQTT Broker: $script:BROKER`:$script:PORT" -ForegroundColor Green
        } else {
            Write-Host "MQTT CONNACK failed: $($response -join ' ')" -ForegroundColor Red
            $script:mqttConnected = $false
        }
    }
    catch {
        Write-Host "Warning: Could not connect to MQTT Broker: $_" -ForegroundColor Yellow
        $script:mqttConnected = $false
    }
}

function Publish-MQTTMessage {
    param(
        [string]$topic,
        [string]$message
    )
    
    if ($script:mqttConnected -and $script:mqttClient.Connected) {
        try {
            $topicBytes   = [System.Text.Encoding]::UTF8.GetBytes($topic)
            $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($message)

            $variableHeader = @(
                [byte]($topicBytes.Length -shr 8),     # Topic length MSB
                [byte]($topicBytes.Length -band 0xFF)  # Topic length LSB
            ) + $topicBytes

            $remainingLength = $variableHeader.Length + $messageBytes.Length
            $fixedHeader = @(0x30, [byte]$remainingLength)  # PUBLISH, QoS 0

            $packet = [byte[]]($fixedHeader + $variableHeader + $messageBytes)
            $script:mqttStream.Write($packet, 0, $packet.Length)
            $script:mqttStream.Flush()

            Write-Host "MQTT Published: $topic = $message" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error publishing to MQTT: $_" -ForegroundColor Red
        }
    }
}

function Disconnect-MQTT {
    if ($script:mqttClient) {
        try {
            # Send MQTT DISCONNECT packet
            if ($script:mqttStream) {
                $packet = [byte[]](0xE0, 0x00)
                $script:mqttStream.Write($packet, 0, $packet.Length)
                $script:mqttStream.Flush()
            }
            $script:mqttClient.Close()
            $script:mqttConnected = $false
            Write-Host "Disconnected from MQTT Broker" -ForegroundColor Green
        }
        catch {
            Write-Host "Error disconnecting from MQTT: $_" -ForegroundColor Yellow
        }
    }
}

# Color cycling functions
function Red {
    $script:red = if ($script:red -eq 0) { 1 } elseif ($script:red -eq 1) { 2 } else { 0 }
    Write-Host "r=$script:red"
    Publish-MQTTMessage -topic "status/red" -message "$script:red"
}

function Orange {
    $script:orange = if ($script:orange -eq 0) { 1 } elseif ($script:orange -eq 1) { 2 } else { 0 }
    Write-Host "o=$script:orange"
    Publish-MQTTMessage -topic "status/orange" -message "$script:orange"
}

function Green {
    $script:green = if ($script:green -eq 0) { 1 } elseif ($script:green -eq 1) { 2 } else { 0 }
    Write-Host "g=$script:green"
    Publish-MQTTMessage -topic "status/green" -message "$script:green"
}

function Blue {
    $script:blue = if ($script:blue -eq 0) { 1 } elseif ($script:blue -eq 1) { 2 } else { 0 }
    Write-Host "b=$script:blue"
    Publish-MQTTMessage -topic "status/blue" -message "$script:blue"
}

function White {
    $script:white = if ($script:white -eq 0) { 1 } elseif ($script:white -eq 1) { 2 } else { 0 }
    Write-Host "w=$script:white"
    Publish-MQTTMessage -topic "status/white" -message "$script:white"
}

function Buzzerc {
    $script:buzzerc = if ($script:buzzerc -eq 0) { 1 } else { 0 }
    Write-Host "bc=$script:buzzerc"
    Publish-MQTTMessage -topic "status/buzzer_continous" -message "$script:buzzerc"
}

function Buzzerp {
    $script:buzzerp = if ($script:buzzerp -eq 0) { 1 } else { 0 }
    Write-Host "bp=$script:buzzerp"
    Publish-MQTTMessage -topic "status/buzzer_pulsing" -message "$script:buzzerp"
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

# Initialize MQTT connection
Initialize-MQTT

Write-Host ""
Write-Host "Available hotkeys:"
Write-Host "  Ctrl+Alt+1 -> Red"
Write-Host "  Ctrl+Alt+2 -> Orange"
Write-Host "  Ctrl+Alt+3 -> Green"
Write-Host "  Ctrl+Alt+4 -> Blue"
Write-Host "  Ctrl+Alt+5 -> White"
Write-Host "  Ctrl+Alt+6 -> Buzzer (Continous)"
Write-Host "  Ctrl+Alt+7 -> Buzzer (Pulsing)"
Write-Host ""

# Hotkey configuration
$hotkeyConfig = @{
    $VK_1 = @{ func = { Red };     name = "Red" }
    $VK_2 = @{ func = { Orange };  name = "Orange" }
    $VK_3 = @{ func = { Green };   name = "Green" }
    $VK_4 = @{ func = { Blue };    name = "Blue" }
    $VK_5 = @{ func = { White };   name = "White" }
    $VK_6 = @{ func = { Buzzerc }; name = "Buzzer Continous" }
    $VK_7 = @{ func = { Buzzerp }; name = "Buzzer Pulsing" }
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
        
        Start-Sleep -Milliseconds 10
    }
}
catch {
    Write-Host "Error: $_"
}
finally {
    Write-Host "Hotkey listener stopped."
    Publish-MQTTMessage -topic "status/red" -message "0"
    Publish-MQTTMessage -topic "status/orange" -message "0"
    Publish-MQTTMessage -topic "status/green" -message "0"
    Publish-MQTTMessage -topic "status/blue" -message "0"
    Publish-MQTTMessage -topic "status/white" -message "0"
    Publish-MQTTMessage -topic "status/buzzer_continous" -message "0"
    Publish-MQTTMessage -topic "status/buzzer_pulsing" -message "0"
    
    Write-Host  "Topics set to 0."

    Disconnect-MQTT
}