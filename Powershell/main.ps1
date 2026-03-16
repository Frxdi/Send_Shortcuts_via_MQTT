# ============================================================
# MQTT Hotkey Controller
# ============================================================

# region --- ENV ---

function Load-EnvFile {
    param([string]$envPath)
    
    if (-not (Test-Path $envPath)) {
        Write-Host "Error: .env file not found at $envPath" -ForegroundColor Red
        exit 1
    }
    
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^\s*#') { return }

        if ($_ -match '^\s*([^#=]+)\s*=\s*(.+)$') {
            $name  = $matches[1].Trim()
            $value = $matches[2].Trim()

            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

# endregion

# region --- MQTT ---

function Initialize-MQTT {
    try {
        $script:mqttClient = New-Object System.Net.Sockets.TcpClient
        $script:mqttClient.Connect($script:BROKER, [int]$script:PORT)
        $stream            = $script:mqttClient.GetStream()
        $script:mqttStream = $stream
        $global:mqttStream = $stream
        $global:mqttConnected = $false

        $clientId      = "PS_Client"
        $clientIdBytes = [System.Text.Encoding]::UTF8.GetBytes($clientId)
        $usernameBytes = [System.Text.Encoding]::UTF8.GetBytes($script:MQTT_USER)
        $passwordBytes = [System.Text.Encoding]::UTF8.GetBytes($script:MQTT_PASSWORD)

        $payload = @(0x00, $clientIdBytes.Length) + $clientIdBytes +
                   @(0x00, $usernameBytes.Length) + $usernameBytes +
                   @(0x00, $passwordBytes.Length) + $passwordBytes

        $variableHeader = @(
            0x00, 0x04,
            0x4D, 0x51, 0x54, 0x54,
            0x04,
            0xC2,
            0x00, 0x3C
        )

        $remainingLength = $variableHeader.Length + $payload.Length
        $fixedHeader     = @(0x10, $remainingLength)
        $packet          = [byte[]]($fixedHeader + $variableHeader + $payload)

        $stream.Write($packet, 0, $packet.Length)
        $stream.Flush()

        Start-Sleep -Milliseconds 500
        $response = New-Object byte[] 4
        $stream.Read($response, 0, 4) | Out-Null

        if ($response[0] -eq 0x20 -and $response[3] -eq 0x00) {
            $script:mqttConnected = $true
            $global:mqttConnected = $true
            Write-Host "Connected to MQTT Broker: $script:BROKER`:$script:PORT" -ForegroundColor Green
        } else {
            Write-Host "MQTT CONNACK failed: $($response -join ' ')" -ForegroundColor Red
            $script:mqttConnected = $false
            $global:mqttConnected = $false
        }
    }
    catch {
        Write-Host "Warning: Could not connect to MQTT Broker: $_" -ForegroundColor Yellow
        $script:mqttConnected = $false
        $global:mqttConnected = $false
    }
}

function Reconnect-MQTT {
    Write-Host "Verbindung verloren - versuche Reconnect..." -ForegroundColor Yellow

    try {
        if ($script:mqttStream) { $script:mqttStream.Close() }
        if ($script:mqttClient) { $script:mqttClient.Close() }
    } catch { }

    $script:mqttClient    = $null
    $script:mqttStream    = $null
    $script:mqttConnected = $false
    $global:mqttConnected = $false
    $global:mqttStream    = $null

    Start-Sleep -Seconds 5
    Initialize-MQTT

    if ($script:mqttConnected) {
        Write-Host "Reconnect erfolgreich!" -ForegroundColor Green
    } else {
        Write-Host "Reconnect fehlgeschlagen - nächster Versuch in 5s..." -ForegroundColor Red
    }
}

function Test-MQTTConnection {
    if (-not $script:mqttClient) { return $false }
    if (-not $script:mqttClient.Connected) { return $false }

    try {
        $socket         = $script:mqttClient.Client
        $isDisconnected = ($socket.Poll(1000, [System.Net.Sockets.SelectMode]::SelectRead) -and $socket.Available -eq 0)
        return -not $isDisconnected
    } catch {
        return $false
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
                [byte]($topicBytes.Length -shr 8),
                [byte]($topicBytes.Length -band 0xFF)
            ) + $topicBytes

            $remainingLength = $variableHeader.Length + $messageBytes.Length
            $fixedHeader     = @(0x30, [byte]$remainingLength)
            $packet          = [byte[]]($fixedHeader + $variableHeader + $messageBytes)

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
            if ($script:mqttStream) {
                $packet = [byte[]](0xE0, 0x00)
                $script:mqttStream.Write($packet, 0, $packet.Length)
                $script:mqttStream.Flush()
            }
            $script:mqttClient.Close()
            $script:mqttConnected = $false
            $global:mqttConnected = $false
            $global:mqttStream    = $null
            Write-Host "Disconnected from MQTT Broker" -ForegroundColor Green
        }
        catch {
            Write-Host "Error disconnecting from MQTT: $_" -ForegroundColor Yellow
        }
    }
}

# endregion

# region --- COLOR / BUZZER FUNCTIONS ---

function Red {
    $script:red = if ($script:red -eq 0) { 1 } elseif ($script:red -eq 1) { 2 } else { 0 }
    Publish-MQTTMessage -topic "status/red" -message "$script:red"
}

function Orange {
    $script:orange = if ($script:orange -eq 0) { 1 } elseif ($script:orange -eq 1) { 2 } else { 0 }
    Publish-MQTTMessage -topic "status/orange" -message "$script:orange"
}

function Green {
    $script:green = if ($script:green -eq 0) { 1 } elseif ($script:green -eq 1) { 2 } else { 0 }
    Publish-MQTTMessage -topic "status/green" -message "$script:green"
}

function Blue {
    $script:blue = if ($script:blue -eq 0) { 1 } elseif ($script:blue -eq 1) { 2 } else { 0 }
    Publish-MQTTMessage -topic "status/blue" -message "$script:blue"
}

function White {
    $script:white = if ($script:white -eq 0) { 1 } elseif ($script:white -eq 1) { 2 } else { 0 }
    Publish-MQTTMessage -topic "status/white" -message "$script:white"
}

function Buzzerc {
    $script:buzzerc = if ($script:buzzerc -eq 0) { 1 } else { 0 }
    Publish-MQTTMessage -topic "status/buzzer_continous" -message "$script:buzzerc"
}

function Buzzerp {
    $script:buzzerp = if ($script:buzzerp -eq 0) { 1 } else { 0 }
    Publish-MQTTMessage -topic "status/buzzer_pulsing" -message "$script:buzzerp"
}

# endregion

# region --- WIN32 API ---

$Win32Signature = @"
[DllImport("user32.dll")]
public static extern short GetAsyncKeyState(int vKey);
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@
Add-Type -MemberDefinition $Win32Signature -Name MeineWin32API -Namespace Win32

function Test-IsKeyPressed {
    param([int]$vKey)
    $state = [Win32.MeineWin32API]::GetAsyncKeyState($vKey)
    return ($state -band 0x8000) -ne 0
}

# endregion

# region --- SESSION HANDLER ---

$script:sessionHandler = {
    $reason = $Event.SourceArgs[1].Reason

    if ($reason -eq [Microsoft.Win32.SessionSwitchReason]::SessionLock) {
        Write-Host "PC gesperrt" -ForegroundColor Yellow

        $msgs = [ordered]@{
            "status/WinStatus" = "0"
        }

        if ($global:mqttConnected -and $global:mqttStream -ne $null) {
            foreach ($topic in $msgs.Keys) {
                try {
                    $topicBytes   = [System.Text.Encoding]::UTF8.GetBytes($topic)
                    $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($msgs[$topic])
                    $varHeader    = @(
                        [byte]($topicBytes.Length -shr 8),
                        [byte]($topicBytes.Length -band 0xFF)
                    ) + $topicBytes
                    $remaining = $varHeader.Length + $messageBytes.Length
                    $packet    = [byte[]](@(0x30, [byte]$remaining) + $varHeader + $messageBytes)
                    $global:mqttStream.Write($packet, 0, $packet.Length)
                    $global:mqttStream.Flush()
                    Write-Host "Published: $topic = $($msgs[$topic])" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "Lock: Error publishing $topic : $_" -ForegroundColor Red
                }
            }
        }
    }

    if ($reason -eq [Microsoft.Win32.SessionSwitchReason]::SessionUnlock) {
        Write-Host "PC entsperrt" -ForegroundColor Green

        $msgs = [ordered]@{
            "status/WinStatus" = "1"
        }

        if ($global:mqttConnected -and $global:mqttStream -ne $null) {
            foreach ($topic in $msgs.Keys) {
                try {
                    $topicBytes   = [System.Text.Encoding]::UTF8.GetBytes($topic)
                    $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($msgs[$topic])
                    $varHeader    = @(
                        [byte]($topicBytes.Length -shr 8),
                        [byte]($topicBytes.Length -band 0xFF)
                    ) + $topicBytes
                    $remaining = $varHeader.Length + $messageBytes.Length
                    $packet    = [byte[]](@(0x30, [byte]$remaining) + $varHeader + $messageBytes)
                    $global:mqttStream.Write($packet, 0, $packet.Length)
                    $global:mqttStream.Flush()
                    Write-Host "Published: $topic = $($msgs[$topic])" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "Unlock: Error publishing $topic : $_" -ForegroundColor Red
                }
            }
        }
    }
}

# endregion

# region --- INIT / MAIN / CLEANUP ---

function Initialize {
    param([string]$scriptDir)

    $envFilePath = Join-Path $scriptDir ".env"
    Load-EnvFile $envFilePath

    $script:BROKER        = [Environment]::GetEnvironmentVariable('BROKER',        'Process')
    $script:PORT          = [Environment]::GetEnvironmentVariable('PORT',          'Process')
    $script:MQTT_USER     = [Environment]::GetEnvironmentVariable('MQTT_USER',     'Process')
    $script:MQTT_PASSWORD = [Environment]::GetEnvironmentVariable('MQTT_PASSWORD', 'Process')

    if (-not $script:BROKER) {
        Write-Host "Error: BROKER not defined in .env file" -ForegroundColor Red
        [Console]::ReadKey($true) | Out-Null; exit 1
    }
    if (-not $script:PORT) {
        Write-Host "Error: PORT not defined in .env file" -ForegroundColor Red
        [Console]::ReadKey($true) | Out-Null; exit 1
    }
    if (-not $script:MQTT_USER) {
        Write-Host "Error: MQTT_USER not defined in .env file" -ForegroundColor Red
        [Console]::ReadKey($true) | Out-Null; exit 1
    }
    if (-not $script:MQTT_PASSWORD) {
        Write-Host "Error: MQTT_PASSWORD not defined in .env file" -ForegroundColor Red
        [Console]::ReadKey($true) | Out-Null; exit 1
    }

    # State variables
    $script:red            = 0
    $script:orange         = 0
    $script:green          = 0
    $script:blue           = 0
    $script:white          = 0
    $script:buzzerc        = 0
    $script:buzzerp        = 0
    $script:mqttClient     = $null
    $script:mqttStream     = $null
    $script:mqttConnected  = $false
    $script:previousStates = @{}
    $script:running        = $true

    # Connect MQTT
    Initialize-MQTT

    # Register Session Lock/Unlock handler nach MQTT connect
    Add-Type -AssemblyName System.Windows.Forms
    Register-ObjectEvent `
        -InputObject ([Microsoft.Win32.SystemEvents]) `
        -EventName   "SessionSwitch" `
        -Action      $script:sessionHandler | Out-Null

    Write-Host "Session Lock/Unlock listener registered" -ForegroundColor Green

    # Reset all topics
    Publish-MQTTMessage -topic "status/red"              -message "0"
    Publish-MQTTMessage -topic "status/orange"           -message "0"
    Publish-MQTTMessage -topic "status/green"            -message "0"
    Publish-MQTTMessage -topic "status/blue"             -message "0"
    Publish-MQTTMessage -topic "status/white"            -message "0"
    Publish-MQTTMessage -topic "status/buzzer_continous" -message "0"
    Publish-MQTTMessage -topic "status/buzzer_pulsing"   -message "0"
    Publish-MQTTMessage -topic "status/WinStatus"        -message "1"

    # Hide console window
    $consoleHandle = [Win32.MeineWin32API]::GetConsoleWindow()
    [Win32.MeineWin32API]::ShowWindow($consoleHandle, 0) | Out-Null
}

function Main {
    $VK_CONTROL = 0x11
    $VK_MENU    = 0x12
    $VK_0 = 0x30
    $VK_1 = 0x31
    $VK_2 = 0x32
    $VK_3 = 0x33
    $VK_4 = 0x34
    $VK_5 = 0x35
    $VK_6 = 0x36
    $VK_7 = 0x37

    $hotkeyConfig = @{
        $VK_0 = @{ func = { $script:running = $false }; name = "Exit" }
        $VK_1 = @{ func = { Red };     name = "Red" }
        $VK_2 = @{ func = { Orange };  name = "Orange" }
        $VK_3 = @{ func = { Green };   name = "Green" }
        $VK_4 = @{ func = { Blue };    name = "Blue" }
        $VK_5 = @{ func = { White };   name = "White" }
        $VK_6 = @{ func = { Buzzerc }; name = "Buzzer Continous" }
        $VK_7 = @{ func = { Buzzerp }; name = "Buzzer Pulsing" }
    }

    $lastPing            = [DateTime]::Now
    $lastConnectionCheck = [DateTime]::Now
    $MQTT_True           = $false

    while ($script:running) {

        # Windows Message Loop - damit SessionSwitch Events feuern
        [System.Windows.Forms.Application]::DoEvents()

        # Verbindung alle 5 Sekunden prüfen
        if (([DateTime]::Now - $lastConnectionCheck).TotalSeconds -ge 5) {
            $lastConnectionCheck = [DateTime]::Now

            if (-not (Test-MQTTConnection)) {
                Reconnect-MQTT
            }
        }

        # Watchdog Ping
        if (([DateTime]::Now - $lastPing).TotalSeconds -ge 2 -and -not $MQTT_True) {
            Publish-MQTTMessage -topic "status/ping" -message "1"
            $MQTT_True = $true
        }
        if (([DateTime]::Now - $lastPing).TotalSeconds -ge 4) {
            Publish-MQTTMessage -topic "status/ping" -message "0"
            $lastPing  = [DateTime]::Now
            $MQTT_True = $false
        }

        $ctrlPressed    = Test-IsKeyPressed $VK_CONTROL
        $altPressed     = Test-IsKeyPressed $VK_MENU
        $ctrlAltPressed = $ctrlPressed -and $altPressed

        foreach ($vk in $hotkeyConfig.Keys) {
            $isPressed = Test-IsKeyPressed $vk

            if (-not $script:previousStates.ContainsKey($vk)) {
                $script:previousStates[$vk] = $false
            }

            if ($isPressed -and -not $script:previousStates[$vk] -and $ctrlAltPressed) {
                $script:previousStates[$vk] = $true
                & $hotkeyConfig[$vk].func
            }
            elseif (-not $isPressed) {
                $script:previousStates[$vk] = $false
            }
        }

        Start-Sleep -Milliseconds 10
    }
}

function Cleanup {
    Get-EventSubscriber | Where-Object { $_.EventName -eq "SessionSwitch" } | Unregister-Event

    Publish-MQTTMessage -topic "status/red"              -message "0"
    Publish-MQTTMessage -topic "status/orange"           -message "0"
    Publish-MQTTMessage -topic "status/green"            -message "0"
    Publish-MQTTMessage -topic "status/blue"             -message "0"
    Publish-MQTTMessage -topic "status/white"            -message "0"
    Publish-MQTTMessage -topic "status/buzzer_continous" -message "0"
    Publish-MQTTMessage -topic "status/buzzer_pulsing"   -message "0"
    Publish-MQTTMessage -topic "status/WinStatus"        -message "0"

    Disconnect-MQTT
}

# endregion

# --- Programm Start ---
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

try {
    Initialize -scriptDir $scriptDirectory
    Main
}
finally {
    Cleanup
}