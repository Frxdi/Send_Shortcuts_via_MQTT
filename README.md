# Status Teams Localhost - MQTT Control Script

This PowerShell script uses keyboard shortcuts to control status indicators and send MQTT commands to a configurable MQTT Broker.

## Features

- **Hotkey Control**: Press keyboard shortcuts to toggle status states
- **MQTT Integration**: Automatically publishes state changes to an MQTT broker
- **Configurable**: All settings are loaded from a `.env` file
- **State Management**: Tracks color and buzzer states (Red/Orange/Green/Blue/White and Buzzer Correct/Problem)

## Configuration

The script uses a `.env` file for configuration with the following variables:

```
BROKER=127.0.0.1               # MQTT Broker IP address or hostname
PORT=1883                      # MQTT Broker port (default MQTT port is 1883)
MQTT_USER="yourUser"           # Username which has to be valid for the MQTT Broker 
MQTT_PASSWORD="yourPassword"   # Password which has to be valid for the MQTT Broker 
```

### Updating Configuration

Edit the `.env` file to change the MQTT broker settings:

```bash
BROKER=your.mqtt.broker.com
PORT=1883
MQTT_USER="yourUser"
MQTT_PASSWORD="yourPassword"
```

## Running the Script

### Prerequisites

- PowerShell 5.1 or higher
- Access to an MQTT Broker at the configured address and port
- Execution Policy must allow script execution

### Execution

1. Open PowerShell as Administrator
2. Navigate to the script directory:
   ```powershell
   cd "Your_Path\"
   ```

3. Run the script:
   ```powershell
   .\main.ps1
   ```

4. If you get an execution policy error, run:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Hotkeys

The following keyboard shortcuts are available:

| Shortcut | Function | MQTT Topic |
|----------|----------|-----------|
| Ctrl+Alt+1 | Toggle Red (0→1→2→0) | `status/red` |
| Ctrl+Alt+2 | Toggle Orange (0→1→2→0) | `status/orange` |
| Ctrl+Alt+3 | Toggle Green (0→1→2→0) | `status/green` |
| Ctrl+Alt+4 | Toggle Blue (0→1→2→0) | `status/blue` |
| Ctrl+Alt+5 | Toggle White (0→1→2→0) | `status/white` |
| Ctrl+Alt+6 | Toggle Buzzer (Correct) (0→1→0) | `status/buzzer_correct` |
| Ctrl+Alt+7 | Toggle Buzzer (Problem) (0→1→0) | `status/buzzer_problem` |
| Ctrl+C | Exit Script | N/A |

## How It Works

1. **Startup**: The script loads configuration from `.env` and attempts to connect to the MQTT broker
2. **Hotkey Listening**: Uses Windows API to detect global hotkey combinations (Ctrl+Alt+Number)
3. **State Management**: When a hotkey is pressed, the corresponding state cycles through its values
4. **MQTT Publishing**: Each state change is published to the MQTT broker on its respective topic
5. **Shutdown**: When you press Ctrl+C, the script gracefully disconnects from the MQTT broker

## MQTT Message Format

When a state changes, the script publishes:
- **Topic**: `status/{color_or_buzzer}`
- **Message**: The new state value (0, 1, or 2)

Example:
- Press Ctrl+Alt+1 → Publishes `1` to topic `status/red`
- Press Ctrl+Alt+1 again → Publishes `2` to topic `status/red`
- Press Ctrl+Alt+1 again → Publishes `0` to topic `status/red`

## Troubleshooting

### Script won't connect to MQTT broker
- Verify the BROKER and PORT in `.env` are correct
- Ensure the MQTT broker is running and accessible
- Check firewall settings to allow outbound connections on the MQTT port

### Hotkeys not responding
- Ensure PowerShell window is running in the background
- Try running as Administrator
- Check if another application is intercepting the hotkeys

### Configuration not loading
- Verify `.env` file exists in the same directory as `main.ps1`
- Check that `BROKER` and `PORT` lines have no extra spaces
- Format should be: `VAR_NAME=value` (no spaces around `=`)

## Files

- `main.ps1` - Main PowerShell script with hotkey listener and MQTT integration
- `.env` - Configuration file with MQTT broker settings
- `README.md` - This documentation file
- `Mqtt.py` - Legacy Python implementation (for reference)
- `Test.py` - Test implementation (for reference)
