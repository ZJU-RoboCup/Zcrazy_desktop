# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Zcrazy is a desktop application for controlling and monitoring SSL (Small Size League) robot soccer robots. It uses PyQt6 with a QML frontend and communicates with robots over UDP via Protocol Buffers.

## Build & run

This project uses the conda environment `zcrazy` (Anaconda, Python 3.13).

```bash
# Activate environment
source activate zcrazy    # Linux / Git Bash
conda activate zcrazy     # Windows cmd / PowerShell

# Run directly
python main.py

# Generate protobuf bindings (only when .proto files change)
protoc --python_out=. zss_cmd_type.proto zss_cmd.proto

# Build Windows EXE
pyinstaller --noconfirm --clean zcrazy.spec
# Output: dist/zcrazy.exe

# Build Linux AppImage
chmod +x build_appimage.sh
./build_appimage.sh
# Output: zcrazy-x86_64.AppImage
```

## Architecture

The codebase has three main layers connected by Qt signals and a QML UI layer:

### Communication layer (`network.py`)
- `QtMulticastReceiver` — binds to `225.225.225.225:13134`, joins multicast group, emits `dataReceived(bytes, ip_str)` for every robot status broadcast
- `QtPointToPointReceiver` — binds to `0.0.0.0:14134`, filters datagrams by `target_ip` and `receive_flag`, used to receive detailed `Robot_Status` from a single selected robot
- `QtUdpSender` — sends `Robot_Command` protobuf to individual robots on port 14234

### Protocol layer (`zss_cmd.proto`, `zss_cmd_type.proto`, `*_pb2.py`)
- `Multicast_Status` — lightweight robot heartbeat (team, ID, battery, capacitance, infrared, IMU flag)
- `Robot_Status` — detailed per-robot telemetry (wheel encoders, IMU data, odometry)
- `Robot_Command` — velocity/pose/chase/wheel commands, kick/dribble control, team/ID change requests

### Core application (`main.py`)
- **`InfoReceiver`** — deserializes incoming `Multicast_Status` from the multicast receiver, stores by `{addr: pb_info}`, calls a callback on each new status packet
- **`CmdSender`** — builds and serializes `Robot_Command` messages. Implements trapezoidal velocity ramping (accel-limited toward targets at 8ms intervals), trajectory playback (square, rectangle, circle, custom polygon paths), emergency stop, team/ID change with repeated send
- **`InfoViewer`** (QQuickPaintedItem registered as `ZSS.InfoViewer`) — paints robot status cards in two columns (blue team left, yellow team right). Handles mouse clicks to select/deselect robots, displays detailed telemetry from the point-to-point stream, exposes QML-callable slots for all robot commands. Manages robot online tracking with a 6-second removal grace period and delay statistics
- **Plotting** — optional `pyqtgraph` window showing real-time robot telemetry fields configured via `zcrazy.txt`

### QML UI layer
- `main.qml` — root `ApplicationWindow`, splits into control panel (left) and `InfoViewer` (right, 650px), runs an 8ms `Timer` that calls `infoViewer.sendCommand()`
- `UI.qml` — control panel with velocity sliders, kick/dribble controls, trajectory editor, team/ID change, and all-robot selection. Binds directly to `cmdSender` (the `InfoViewer` instance)
- `ZGroupBox.qml`, `ZText.qml` — reusable QML components for consistent styling

### Data flow
```
Robots (UDP multicast) → QtMulticastReceiver → InfoReceiver._cb() → InfoViewer.getNewInfo() → paint thread
Robots (UDP unicast)   → QtPointToPointReceiver → parse_and_paint_signal() → paint_single_info()
UI controls            → InfoViewer.updateCommandParams() → CmdSender.updateCommandParams()
8ms Timer              → InfoViewer.sendCommand() → CmdSender.sendCommand() → QtUdpSender → robots
```

## Key design decisions

- **Velocity ramping**: Linear accel 16000 mm/s², angular accel 60 rad/s². IMU angle commands bypass ramping and are applied immediately.
- **Team/ID change**: Repeated packets sent for ~1.6s (200 ticks × 8ms) to handle UDP loss. The pending change is finalized when the multicast status confirms the new team/ID.
- **Robot removal**: Robots disappear from UI 6 seconds after their last multicast packet. This avoids flicker from brief network hiccups.
- **Resource paths**: `resource_path()` supports both development (`os.path.abspath(".")`) and PyInstaller-packaged mode (`sys._MEIPASS`). All QML/data files must be listed in both `zcrazy.spec:datas` and the `PACKAGING.md` documentation.
- **Software rendering**: Defaulted via environment variables for AppImage compatibility (no GLX/EGL dependency).
- **zcrazy.txt**: Configuration file that controls whether plotting is enabled and which protobuf fields to plot. Format: `true:` on line 1, then field paths prefixed with `-` for command-side fields.
