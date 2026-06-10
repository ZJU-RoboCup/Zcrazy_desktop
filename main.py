# udp receiver for multicast
import json
import math
import os
import sys, socket, threading, time
from collections import deque
from PyQt6.QtGui import QFont, QPainter, QColor, QImage, QMouseEvent, QPen
from PyQt6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PyQt6.QtQuick import QQuickPaintedItem
from PyQt6.QtCore import Qt,QRectF,QRect,QSize,pyqtSlot,pyqtSignal,QTimer
from PyQt6.QtCore import pyqtProperty

from PyQt6.QtWidgets import  QApplication

import pyqtgraph as pg

import zss_cmd_pb2 as zss
import zss_cmd_type_pb2 as zss_type

import network
from datetime import datetime

fdbNeedPlotName = []
refNeedPlotName = []
fdbPlotForward = "info."
refPlotForward = "self.pb_data."
    
needPlot = True
# plotDataNum = 0
# plotInitFinish = False

# plotData = [0]*plotDataNum
# plotDataList = [[] for _ in range(plotDataNum)]

onlineLock = threading.Lock()
changeSendTick = 0
changeSendTickLock = threading.Lock()

# Change-team/id commands need repeated packets in case of UDP loss.
# The UI sends packets every ~8ms (see QML Timer), so 200 ticks ~ 1.6s.
CHANGE_SEND_TICK_MAX = 200

ipForward = "192.168.31"

onlineTick = [0]*32

# Vehicle display stability: allow short multicast hiccups without immediately hiding robots.
# A robot is only removed from the UI after it has not been seen for this long.
ONLINE_REMOVE_AFTER_MS = 6000

# "Delay" here is computed as: now_ms - last_seen_ms (i.e. data age).
HIGH_DELAY_WARN_MS = 1200

# Smoothing for delay display: compute a 1-second sliding-window mean.
DELAY_AVG_WINDOW_MS = 1000

MC_ADDR = "225.225.225.225"
MC_PORT = 13134
SEND_PORT = 14234
SINGLE_PORT = 14134
TRAJECTORY_HISTORY_FILE = "trajectory_history.json"


def percent_from_raw_battery(raw10x: int) -> int:
    """Match percentFromRawBattery() in RobotStatusModel.cpp.

    raw10x: battery total voltage in 10x volts (e.g. 151 -> 15.1V)
    returns: 0..100
    """
    if raw10x <= 0:
        return 0
    volts = raw10x / 10.0
    # Infer cell count: prefer 4S, otherwise 3S (avoid misclassifying 3S full 12.6V as 4S)
    cells = 4 if volts >= 13.0 else 3
    per_cell = volts / cells

    v_tab = [
        4.20, 4.15, 4.10, 4.05, 4.00, 3.95, 3.92, 3.88, 3.84,
        3.80, 3.78, 3.75, 3.72, 3.70, 3.68, 3.65, 3.62, 3.55, 3.30,
    ]
    p_tab = [
        100, 95, 90, 85, 80, 75, 70, 60, 50,
        45, 40, 35, 30, 25, 20, 15, 10, 5, 0,
    ]

    if per_cell >= v_tab[0]:
        return 100
    if per_cell <= v_tab[-1]:
        return 0

    for i in range(len(v_tab) - 1):
        v_high = v_tab[i]
        v_low = v_tab[i + 1]
        if v_low <= per_cell <= v_high:
            p_high = p_tab[i]
            p_low = p_tab[i + 1]
            t = (per_cell - v_low) / (v_high - v_low)
            p = int(round(p_low + t * (p_high - p_low)))
            return max(0, min(100, p))

    # Fallback (should not reach)
    p = int(round((per_cell - 3.30) / (4.20 - 3.30) * 100.0))
    return max(0, min(100, p))


def resource_path(rel_path: str) -> str:
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, rel_path)
    return os.path.join(os.path.abspath("."), rel_path)

# udp receiver for multicast
def get_ip_address():
    hostname = socket.gethostname()
    ip_address = socket.gethostbyname(hostname)
    return ip_address

local_ip=get_ip_address()
print("本机IP地址是:", local_ip)
class InfoReceiver:
    info = {}
    selected = {}
    def __init__(self,info_cb = None):
        self.info = {}
        self.info_cb = info_cb
    def _cb(self,data,addr):
        pb_info = zss.Multicast_Status()
        pb_info.ParseFromString(data)
        pb_info.ip = int(addr.split(".")[3])
        self.info[addr] = pb_info  
        if self.info_cb is not None:
            self.info_cb(pb_info.robot_id,pb_info)
                     
class CmdSender:
    def __init__(self):
        self.udpSender = network.QtUdpSender()
        self.pb_data = zss.Robot_Command()
        self.pb_data.robot_id = -1
        self.pb_data.kick_mode = zss.Robot_Command.KickMode.NONE
        # self.pb_data.desire_power = power
        self.pb_data.kick_discharge_time = 0
        self.pb_data.dribble_spin = 0
        self.pb_data.dribble_velocity = int(-50.0 * 100.0)
        self.pb_data.dribble_torque_ff = int(0.1 * 1000.0)
        self.pb_data.cmd_type = zss.Robot_Command.CmdType.CMD_VEL
        self.pb_data.cmd_vel.velocity_x = int(0*1000)
        self.pb_data.cmd_vel.velocity_y = int(0*1000)
        self.pb_data.cmd_vel.velocity_r = int(0*1000)
        self.pb_data.cmd_vel.use_imu = False
        self.pb_data.cmd_vel.imu_theta = int(0*3.1415926/180.0*1000)
        self.pb_data.comm_type = zss.Robot_Command.CommType.UDP_WIFI
        self.pb_data.angle_pid.append(int(6.5*1000))
        self.pb_data.angle_pid.append(int(0*1000))
        self.pb_data.angle_pid.append(int(0.8*1000))
        self.pb_data.need_change_team = False
        self.pb_data.need_change_id = False
        self.pb_data.team_new = zss.Team.UNKNOWN
        self.pb_data.id_new = -1
        self.pb_data.isdebug = True
        self._trajectory_active = False
        self._trajectory_segments = []
        self._trajectory_segment_index = 0
        self._trajectory_segment_started = 0.0
        self._trajectory_loop_remaining = 0
        pass

    def _apply_velocity(self, vx_mm_s: float, vy_mm_s: float, vr_rad_s: float):
        self.pb_data.cmd_vel.use_imu = False
        self.pb_data.cmd_vel.imu_theta = 0
        self.pb_data.cmd_vel.velocity_x = int(round(vx_mm_s))
        self.pb_data.cmd_vel.velocity_y = int(round(vy_mm_s))
        self.pb_data.cmd_vel.velocity_r = int(round(vr_rad_s * 1000.0))

    def _build_trajectory_segments(self, spec: dict) -> list[dict]:
        shape = str(spec.get("shape", "square")).lower()
        speed = max(1.0, float(spec.get("speed", 500.0)))
        length = max(1.0, float(spec.get("length", 1000.0)))
        width = max(1.0, float(spec.get("width", length)))
        clockwise = bool(spec.get("clockwise", False))

        def straight(distance_mm: float, vx_sign: int, vy_sign: int) -> dict:
            return {
                "duration": abs(distance_mm) / speed,
                "vx": speed * vx_sign,
                "vy": speed * vy_sign,
                "vr": 0.0,
            }

        if shape == "square":
            return [
                straight(length, 1, 0),
                straight(length, 0, 1),
                straight(length, -1, 0),
                straight(length, 0, -1),
            ]

        if shape == "rectangle":
            return [
                straight(length, 1, 0),
                straight(width, 0, 1),
                straight(length, -1, 0),
                straight(width, 0, -1),
            ]

        if shape == "circle":
            radius = max(1.0, length / 2.0)
            direction = -1.0 if clockwise else 1.0
            return [{
                "duration": 2.0 * math.pi * radius / speed,
                "vx": speed,
                "vy": 0.0,
                "vr": direction * speed / radius,
            }]

        if shape == "custom":
            points = spec.get("points", [])
            if len(points) < 2:
                raise ValueError("custom trajectory needs at least 2 points")
            if bool(spec.get("closePath", False)):
                first = points[0]
                last = points[-1]
                if float(first.get("x", 0)) != float(last.get("x", 0)) or float(first.get("y", 0)) != float(last.get("y", 0)):
                    points = points + [dict(first)]

            segments = []
            for prev, cur in zip(points, points[1:]):
                x0 = float(prev.get("x", 0.0))
                y0 = float(prev.get("y", 0.0))
                x1 = float(cur.get("x", 0.0))
                y1 = float(cur.get("y", 0.0))
                dx = x1 - x0
                dy = y1 - y0
                dist = math.hypot(dx, dy)
                if dist < 1e-6:
                    continue
                segments.append({
                    "duration": dist / speed,
                    "vx": speed * dx / dist,
                    "vy": speed * dy / dist,
                    "vr": 0.0,
                })
            if not segments:
                raise ValueError("custom trajectory has no non-zero segments")
            return segments

        raise ValueError(f"unsupported trajectory shape: {shape}")

    def startTrajectory(self, spec_json: str) -> bool:
        try:
            spec = json.loads(spec_json)
            segments = self._build_trajectory_segments(spec)
            repeat = max(1, int(spec.get("repeat", 1)))
        except Exception as e:
            print(f"[WARN] startTrajectory failed: {e}")
            return False

        self._trajectory_segments = segments
        self._trajectory_segment_index = 0
        self._trajectory_segment_started = time.monotonic()
        self._trajectory_loop_remaining = repeat
        self._trajectory_active = True
        first = self._trajectory_segments[0]
        self._apply_velocity(first["vx"], first["vy"], first["vr"])
        print(f"[INFO] trajectory started: {len(segments)} segment(s), repeat={repeat}")
        return True

    def stopTrajectory(self):
        self._trajectory_active = False
        self._trajectory_segments = []
        self._trajectory_segment_index = 0
        self._trajectory_loop_remaining = 0
        self._apply_velocity(0.0, 0.0, 0.0)

    def _advance_trajectory(self):
        if not self._trajectory_active or not self._trajectory_segments:
            return

        now = time.monotonic()
        segment = self._trajectory_segments[self._trajectory_segment_index]
        if now - self._trajectory_segment_started < segment["duration"]:
            self._apply_velocity(segment["vx"], segment["vy"], segment["vr"])
            return

        self._trajectory_segment_index += 1
        if self._trajectory_segment_index >= len(self._trajectory_segments):
            self._trajectory_loop_remaining -= 1
            if self._trajectory_loop_remaining <= 0:
                self.stopTrajectory()
                print("[INFO] trajectory finished.")
                return
            self._trajectory_segment_index = 0

        self._trajectory_segment_started = now
        segment = self._trajectory_segments[self._trajectory_segment_index]
        self._apply_velocity(segment["vx"], segment["vy"], segment["vr"])
    # updateCommandParams(int robotID,double velX,double velY,double velR,double ctrl,bool mode,bool shoot,double power,bool use_imu,double angle,double dribble_velocity,double dribble_torque_ff)
    # 在UI.qml中调用来传递控制指令
    def updateCommandParams(self,robotID,velX,velY,velR,ctrl,mode,shoot,power,use_imu,angle,dribble_velocity,dribble_torque_ff):
        # self.pb_data = zss.Robot_Command()
        self.pb_data.robot_id = -1
        self.pb_data.kick_mode = zss.Robot_Command.KickMode.NONE if not shoot else (zss.Robot_Command.KickMode.CHIP if mode else zss.Robot_Command.KickMode.KICK)
        # self.pb_data.desire_power = power
        self.pb_data.kick_discharge_time = int(power)
        # print(power)
        self.pb_data.dribble_spin = int(ctrl)
        self.pb_data.dribble_velocity = int(round(dribble_velocity * 100.0))
        self.pb_data.dribble_torque_ff = int(round(dribble_torque_ff * 1000.0))
        self.pb_data.cmd_type = zss.Robot_Command.CmdType.CMD_VEL
        self.pb_data.cmd_vel.velocity_x = int(velX*1000.0)
        self.pb_data.cmd_vel.velocity_y = int(velY*1000.0)
        if use_imu:
            wrapped_angle = angle % 360
            if wrapped_angle > 180:
                wrapped_angle -= 360
            angle_cmd = int(wrapped_angle*3.1415926/180.0*1000)
            self.pb_data.cmd_vel.velocity_r = angle_cmd
            self.pb_data.cmd_vel.imu_theta = angle_cmd
        else:
            self.pb_data.cmd_vel.velocity_r = int(velR*1000.0)
            self.pb_data.cmd_vel.imu_theta = 0
        self.pb_data.cmd_vel.use_imu = use_imu
        # self.pb_data.cmd_vel.imu_theta = angle*3.1415926/180.0
        self.pb_data.comm_type = zss.Robot_Command.CommType.UDP_WIFI
        self.pb_data.angle_pid.clear()
        self.pb_data.angle_pid.append(int(6.5*1000.0))
        self.pb_data.angle_pid.append(int(0*1000.0))
        self.pb_data.angle_pid.append(int(0.5*1000.0))
        self.pb_data.wheel_pid.clear()
        self.pb_data.wheel_pid.append(int(0.1*1000.0))
        self.pb_data.wheel_pid.append(int(0.6*1000.0))
        self.pb_data.wheel_pid.append(int(0*1000.0))
        self.pb_data.isdebug = True
          
    def changeTeam(self, team_new):
        self.pb_data.need_change_team = True
        self.pb_data.team_new = team_new
        global changeSendTick
        changeSendTick = 0

    def changeId(self, id_new):
        self.pb_data.need_change_id = True
        self.pb_data.id_new = id_new
        global changeSendTick
        changeSendTick = 0

    def emergencyStop(self):
        # Immediately send zero velocity (no trapezoid ramp)
        self._trajectory_active = False
        self._trajectory_segments = []
        self.pb_data.cmd_vel.use_imu = False
        self.pb_data.cmd_vel.imu_theta = 0
        self.pb_data.cmd_vel.velocity_x = 0
        self.pb_data.cmd_vel.velocity_y = 0
        self.pb_data.cmd_vel.velocity_r = 0

    def sendCommand(self,infoReceiver:InfoReceiver):
        # print("sendCommand",str(self.pb_data))
        global changeSendTick
        if self.pb_data.need_change_team or self.pb_data.need_change_id:
            changeSendTick += 1
            if changeSendTick >= CHANGE_SEND_TICK_MAX:
                self.pb_data.need_change_team = False
                self.pb_data.need_change_id = False
                    
        # print("debug")
        selectedDir = infoReceiver.selected

        self._advance_trajectory()
        global ipForward 
        ipForward_t = ipForward
        for id,info in selectedDir.items():
            
            global plotData
            global plotInitFinish

            if plotInitFinish: 
                for i in range(len(refNeedPlotName)):
                    plotData[i+len(fdbNeedPlotName)] = eval(refNeedPlotName[i])
              
            self.pb_data.robot_id = id
            # print("sendIp: ",info.ip)
            # Serialize    
            # print("send",self.pb_data.need_change_team, self.pb_data.need_change_id)
            data = self.pb_data.SerializeToString()
            # print(len(data))
            self.udpSender.send(data, ipForward_t+"."+format(info.ip), SEND_PORT)


#inforeceiver的拿到了一个paintinfo的回调函数 udprecv开了一个线程 一直执行receive 收到了就执行inforeceriver的本身的回调函数填数组 再执行paintinfo
class InfoViewer(QQuickPaintedItem):
    MAX_PLAYER = 16
    drawSignal = pyqtSignal(int,zss.Multicast_Status)
    statusSingnal=pyqtSignal(zss.Robot_Status)
    refresh=pyqtSignal(int)
    onlineCountsChanged = pyqtSignal()
    flag1=0
    flag2=0
    update_control=0
    only_one = True
    initFinish = False
    infoReceiverLock = threading.Lock()
    control_all = False
    control_all_which_team = False
    control_all_finish = False
    def __init__(self,parent=None):
        super().__init__(parent)
        # Pending change request that will be finalized when multicast status confirms it.
        # Format: {
        #   'old_key': int, 'new_key': int, 'ip_last': int,
        #   'team': int, 'id': int, 'started_ms': int, 'deadline_ms': int
        # }
        self._pending_change = None
        self._online_blue = 0
        self._online_yellow = 0
        self._avg_delay_ms = 0  # smoothed (sliding-window) average
        self._delay_samples = deque()  # (ts_ms, instant_avg_delay_ms)
        self._high_delay_text = "无"
        self._latest_status = None
        self._live_plot_fields = []
        self._live_plot_data = {}
        self._live_plot_curves = {}
        self._live_plot_win = None
        self._live_plot_widget = None
        self._live_plot_tick = 0
        self._live_plot_timer = QTimer()
        self._live_plot_timer.timeout.connect(self._append_live_plot_sample)
        # accept mouse event left click
        self.setAcceptedMouseButtons(Qt.MouseButton.LeftButton | Qt.MouseButton.RightButton)
        self.receiverNeedStop = False
        self.infoReceiver = InfoReceiver(self.getNewInfo)
        self.cmdSender = CmdSender()

        self.udpRecv = network.QtMulticastReceiver(MC_ADDR, MC_PORT)
        self.udpRecv.dataReceived.connect(self.infoReceiver._cb)

        self.pointtopointRecv = network.QtPointToPointReceiver('0.0.0.0', SINGLE_PORT)
        self.pointtopointRecv.dataReceived.connect(self.parse_and_paint_signal)

        self.ifDraw = [False] * 32
        self.paintTimer = QTimer()
        self.paintTimer.timeout.connect(self.paintAllCheck)
        self.paintTimer.start(200)

        self.painter = QPainter()
        self.image = QImage(QSize(int(self.width()),int(self.height())),QImage.Format.Format_ARGB32_Premultiplied)
        self.ready = False
        self.drawSignal.connect(self.paintInfo)
        self.statusSingnal.connect(self.paint_single_info)
        self.refresh.connect(self.paintRefresh)
        self.initFinish = True

    def _recalc_online_stats(self):
        now_ms = int(datetime.now().timestamp() * 1000)

        blue = 0
        yellow = 0
        delays: list[tuple[int, int]] = []  # (delay_ms, slot_index)
        seen = set()
        for info in self.infoReceiver.info.values():
            slot = int(info.robot_id) + (int(info.team) - 1) * 16
            key = (int(info.team), int(info.robot_id))
            if key in seen:
                continue
            seen.add(key)
            if int(info.team) == 1:
                blue += 1
            elif int(info.team) == 2:
                yellow += 1

            last_seen = 0
            try:
                onlineLock.acquire()
                last_seen = int(onlineTick[slot]) if 0 <= slot < len(onlineTick) else 0
            finally:
                onlineLock.release()
            if last_seen > 0:
                delay_ms = max(0, now_ms - last_seen)
                # Only consider robots still within the display grace period.
                if delay_ms <= ONLINE_REMOVE_AFTER_MS:
                    delays.append((delay_ms, slot))

        instant_avg_delay_ms = int(round(sum(d for d, _ in delays) / len(delays))) if delays else 0

        # Maintain a 1-second sliding window over instant average samples.
        if delays:
            self._delay_samples.append((now_ms, instant_avg_delay_ms))
            cutoff = now_ms - DELAY_AVG_WINDOW_MS
            while self._delay_samples and self._delay_samples[0][0] < cutoff:
                self._delay_samples.popleft()
            avg_delay_ms = int(round(sum(v for _, v in self._delay_samples) / len(self._delay_samples))) if self._delay_samples else instant_avg_delay_ms
        else:
            # No online robots: reset window.
            self._delay_samples.clear()
            avg_delay_ms = 0

        high_delay_text = "无"
        if delays:
            worst_delay_ms, worst_slot = max(delays, key=lambda x: x[0])
            if worst_delay_ms >= HIGH_DELAY_WARN_MS:
                worst_team = 1 if worst_slot < 16 else 2
                worst_id = worst_slot % 16
                team_cn = "蓝" if worst_team == 1 else "黄"
                high_delay_text = f"{team_cn}{worst_id} {worst_delay_ms}ms"

        changed = (
            blue != self._online_blue
            or yellow != self._online_yellow
            or avg_delay_ms != self._avg_delay_ms
            or high_delay_text != self._high_delay_text
        )
        if changed:
            self._online_blue = blue
            self._online_yellow = yellow
            self._avg_delay_ms = avg_delay_ms
            self._high_delay_text = high_delay_text
            self.onlineCountsChanged.emit()

    @pyqtProperty(int, notify=onlineCountsChanged)
    def onlineBlueCount(self):
        return int(self._online_blue)

    @pyqtProperty(int, notify=onlineCountsChanged)
    def onlineYellowCount(self):
        return int(self._online_yellow)

    @pyqtProperty(int, notify=onlineCountsChanged)
    def avgDelayMs(self):
        return int(self._avg_delay_ms)

    @pyqtProperty(str, notify=onlineCountsChanged)
    def highDelayRobot(self):
        return str(self._high_delay_text)
                
    def parse_and_paint_signal(self, data, ip_str):
        if self.ready and self.painter.isActive():
            robot_status = zss.Robot_Status()
            robot_status.ParseFromString(data)
            self.statusSingnal.emit(robot_status)

    def paintAllCheck(self):
        onlineTick_t = onlineTick
        now = int(datetime.now().timestamp() * 1000)  
        
        for i in range(32):
            infoDir = self.infoReceiver.info
            selectDir = self.infoReceiver.selected
            if now - onlineTick_t[i] < ONLINE_REMOVE_AFTER_MS:
                for info in list(infoDir.values()):
                    if (info.team-1)*16 + info.robot_id == i:
                        self.drawSignal.emit(i%16,info)
                        self.ifDraw[i] = True
            else:
                if self.ifDraw[i] == True:
                    self.refresh.emit(i)    
                    info_to_remove = None
                    for key,info in infoDir.items():
                        if info.robot_id+(info.team-1)*16 == i:
                            info_to_remove = key
                    
                    if info_to_remove != None:
                        infoDir.pop(info_to_remove)
                        self.infoReceiver.info = infoDir
                            
                    if i in selectDir.keys():
                        selectDir.pop(i)
                        
                    self.infoReceiver.selected = selectDir
                    self.ifDraw[i] = False 

                # Update online stats after potential removals
                self._recalc_online_stats()

            # Keep delay statistics fresh even when packets pause briefly.
            self._recalc_online_stats()
                
    @pyqtSlot()
    def close(self):
        print("closing info viewer, stop recv thread")
        self.receiverNeedStop = True
        self._live_plot_timer.stop()
        if needPlot:
            timer.stop()
            
    def getNewInfo(self,n,info):
        if self.initFinish:
            global changeSendTick
        # print("got new info ",n,info)
            if self.ready and self.painter.isActive() and n >= 0 and n < self.MAX_PLAYER:
                # print("rev",info.robot_id,info.team)
                onlineLock.acquire()
                onlineTick[info.robot_id + (info.team-1)*16] = int(datetime.now().timestamp() * 1000)
                onlineLock.release()

            # Update online stats on every multicast update
            self._recalc_online_stats()

            # Finalize pending change as soon as multicast reports the new team/id.
            pending = self._pending_change
            if pending is not None:
                now_ms = int(datetime.now().timestamp() * 1000)
                if now_ms > pending['deadline_ms']:
                    print("[WARN] changeTeam/changeId timed out; keeping current selection.")
                    self._pending_change = None
                    self.cmdSender.pb_data.need_change_team = False
                    self.cmdSender.pb_data.need_change_id = False
                    changeSendTick = CHANGE_SEND_TICK_MAX
                    return

                if (
                    info.ip == pending['ip_last']
                    and info.team == pending['team']
                    and info.robot_id == pending['id']
                ):
                    old_key = pending['old_key']
                    new_key = pending['new_key']

                    selected = self.infoReceiver.selected
                    selected_info = selected.pop(old_key, None)
                    if selected_info is not None:
                        selected_info.team = pending['team']
                        selected_info.robot_id = pending['id']
                        selected[new_key] = selected_info
                        self.infoReceiver.selected = selected

                    # Clear old slot immediately (avoid 2s timeout wait).
                    onlineLock.acquire()
                    if 0 <= old_key < len(onlineTick):
                        onlineTick[old_key] = 0
                    onlineLock.release()
                    if 0 <= old_key < len(self.ifDraw):
                        self.ifDraw[old_key] = False
                    self.refresh.emit(old_key)

                    # Stop change flags early; ack already observed.
                    self.cmdSender.pb_data.need_change_team = False
                    self.cmdSender.pb_data.need_change_id = False
                    changeSendTick = CHANGE_SEND_TICK_MAX

                    self._pending_change = None
            # print("online",onlineTick[info.robot_id + (info.team-1)*16],info.robot_id + (info.team-1)*16)
            # self.drawSignal.emit(n,info)    
            
    # 鼠标的功能：总的来说就是确定接收哪个机器人的信息
    # 具体实现就是在指定区域内点击鼠标后，确定一个index，然后找InfoReceiver里的内容，如果找到了，
    # 也就是现在可以和这个index作为id的机器人连接，然后点左键清空缓存，然后确定现在接收内容的机器人id，
    # 然后点其它键，就是手动断开和该index做id的机器人的连接并停止接收
    def mousePressEvent(self, event: QMouseEvent) -> None:
        index, team = self.getAreaIndex(event.pos())
        infoDir = self.infoReceiver.info
        selectDir = self.infoReceiver.selected
        for info in infoDir.values():
            
            if info.robot_id == index and info.team == team:
                if self.only_one:
                    if event.button() == Qt.MouseButton.LeftButton:
                        selectDir.clear()
                        selectDir[index+(info.team-1)*16] = info
                        self.infoReceiver.selected = selectDir
                        global ipForward
                        
                        self.pointtopointRecv.target_ip= ipForward + "."+format(info.ip)
                        self.pointtopointRecv.receive_flag = True
                        # print("else")
                        self.drawSignal.emit(index,info)
                        break
                    else :
                        if (index+(info.team-1)*16) in selectDir:
                            print(selectDir)
                            selectDir.pop(index+(info.team-1)*16)
                            self.infoReceiver.selected = selectDir
                            print(index+(info.team-1)*16)
                            self.pointtopointRecv.receive_flag = False
                            # print("else")
                            self.drawSignal.emit(index,info)
                            return
                else:
                    if event.button() == Qt.MouseButton.LeftButton:
                        selectDir[index+(info.team-1)*16] = info
                        self.infoReceiver.selected = selectDir
                        self.pointtopointRecv.target_ip= ipForward + "."+format(info.ip)
                        self.pointtopointRecv.receive_flag = True
                        # print("else")
                        self.drawSignal.emit(index,info)
                        break
                    else:
                        if (index+(info.team-1)*16) in selectDir:
                            selectDir.pop(index+(info.team-1)*16)
                            self.infoReceiver.selected = selectDir
                            self.pointtopointRecv.receive_flag = False
                            # print("else")
                            self.drawSignal.emit(index,info)
                            return
        

        
            
    @pyqtSlot(int, zss.Multicast_Status)
    def paintInfo(self, n, info):
        selectDir = self.infoReceiver.selected

        battery_percent = percent_from_raw_battery(int(info.battery))
        battery_ratio = battery_percent / 100.0

        # 时尚电量颜色：HSL 模式，饱和度高、亮度高，色相从红(0°)渐变到绿(120°)
        hue = 120 * battery_ratio  # 0→红, 120→绿
        label_color = QColor.fromHsl(int(hue), 245, 230)  # 饱和度255，亮度220(约86%)
        fill_color = label_color  # 直接使用，不再额外提亮

        if info.team == 1:
            # Leave room for left row index labels (0..15)
            area_left = 0.05
            selected = n in selectDir
        else:
            area_left = 0.645
            selected = (n + 16) in selectDir

        # 阴影矩形（偏移量稍加大，颜色加深）
        shadow_rect = QRectF(self._x(n, area_left + 0.014), self._y(n, 0.12),
                            self._w(n, 0.29), self._h(n, 0.83))
        # 卡片矩形（去掉白色背景 panel_rect）
        card_rect = QRectF(self._x(n, area_left + 0.008), self._y(n, 0.06),
                        self._w(n, 0.29), self._h(n, 0.82))

        self.painter.setPen(Qt.PenStyle.NoPen)
        # 绘制阴影（增强：颜色更深）
        self.painter.setBrush(QColor(150, 150, 150, 100))
        self.painter.drawRoundedRect(shadow_rect, 7.5, 7.5)

        # 绘制彩色卡片
        self.painter.setBrush(fill_color)

        # 根据选中状态设置画笔：选中时用亮红色、宽度3；否则用深灰色、宽度1
        if selected:
            pen = QPen(QColor(255, 100, 100), 3)   # 亮红色，宽度3
        else:
            pen = QPen(QColor(45, 45, 45), 1)      # 深灰色，宽度1

        self.painter.setPen(pen)
        self.painter.drawRoundedRect(card_rect, 7.5, 7.5)

        # 绘制文字（无阴影）
        font = QFont('Arial', 10)
        self.painter.setFont(font)
        text = f"{info.ip}: {battery_percent}%,{info.infrared/10.0:.1f},{info.have_imu}"
        self.painter.setPen(QColor(15, 15, 15))
        # Clip to card rect so long text does not overlap middle panel/stats.
        self.painter.save()
        self.painter.setClipRect(card_rect)
        self.painter.drawText(card_rect, Qt.AlignmentFlag.AlignCenter, text)
        self.painter.restore()

        self.update(self._area(n))
        
        
    @pyqtSlot(int)    
    def paintRefresh(self,n):
        if self.initFinish:
            id = n%16
            team = int(n/16)
            self.painter.setPen(QColor(50,50,50))
            self.painter.setBrush(QColor(50,50,50))
            if team == 0:
                # clear blue side including left label strip
                self.painter.drawRect(QRectF(self._x(id,0.0), self._y(id,0.0), self._w(id,0.35),self._h(id,1.0)))

                # redraw left row index label
                self.painter.setPen(QPen(QColor(200, 200, 200), 1))
                self.painter.setBrush(QColor(70, 70, 70))
                self.painter.drawRect(QRectF(self._x(id, 0.0), self._y(id, 0.0),
                                            self._w(id, 0.05), self._h(id, 1.0)))
                self.painter.setFont(QFont('Helvetica', 11))
                self.painter.setPen(QColor(255, 255, 255))
                self.painter.drawText(QRectF(self._x(id, 0.0), self._y(id, 0.0),
                                            self._w(id, 0.05), self._h(id, 1.0)),
                                    Qt.AlignmentFlag.AlignCenter, format(id))
            else:
                # clear yellow side (avoid touching right label strip)
                self.painter.drawRect(QRectF(self._x(id,0.645), self._y(id,0.0), self._w(id,0.305),self._h(id,1.0)))
            self.update()
            self.update(self._area(n))

    def paint(self, painter):
        if self.ready:
            painter.drawImage(QRectF(0,0,self.width(),self.height()),self.image)
        pass
    
    @pyqtSlot(int,int)
    def resize(self, width, height):
        self.ready = False
        if width <= 0 or height <= 0:
            return
        if self.painter.isActive():
            self.painter.end()
        self.image = QImage(QSize(width, height), QImage.Format.Format_ARGB32_Premultiplied)
        self.painter.begin(self.image)
        self.ready = True

        for n in range(16):
            # 绘制整个槽位的灰色背景（保持不变）
            self.painter.setPen(QColor(50, 50, 50))
            self.painter.setBrush(QColor(50, 50, 50))
            self.painter.drawRect(QRectF(self._x(n, 0.0), self._y(n, 0.0),
                                        self._w(n, 1.0), self._h(n, 1.0)))
            self.update()

            # 绘制左侧数字区域：灰色背景，白色边框与文字
            self.painter.setPen(QPen(QColor(200, 200, 200), 1))
            self.painter.setBrush(QColor(70, 70, 70))
            self.painter.drawRect(QRectF(self._x(n, 0.0), self._y(n, 0.0),
                                        self._w(n, 0.05), self._h(n, 1.0)))

            self.painter.setFont(QFont('Helvetica', 11))
            self.painter.setPen(QColor(255, 255, 255))  # 白色文字
            self.painter.drawText(QRectF(self._x(n, 0.0), self._y(n, 0.0),
                                        self._w(n, 0.05), self._h(n, 1.0)),
                                Qt.AlignmentFlag.AlignCenter, format(n))

            # 绘制右侧数字区域：灰色背景，白色边框加粗，白色文字
            # 设置白色画笔，宽度1（加粗）
            self.painter.setPen(QPen(QColor(200, 200, 200), 1))
            # 设置灰色画刷（略亮于主背景，提高可读性）
            self.painter.setBrush(QColor(70, 70, 70))
            self.painter.drawRect(QRectF(self._x(n, 0.95), self._y(n, 0.0),
                                        self._w(n, 0.05), self._h(n, 1.0)))

            # 绘制白色数字
            self.painter.setFont(QFont('Helvetica', 11))
            self.painter.setPen(QColor(255, 255, 255))  # 白色文字
            self.painter.drawText(QRectF(self._x(n, 0.95), self._y(n, 0.0),
                                        self._w(n, 0.05), self._h(n, 1.0)),
                                Qt.AlignmentFlag.AlignCenter, format(n))
            self.update(self._area(n))
        
    def getAreaIndex(self,pos):
        yIndex = int(pos.y()/(self.height()/self.MAX_PLAYER))
        if pos.x() < 0.5 *self.width() :
            team = 1
        else:
            team = 2
        return yIndex,team
    def _area_blue(self,n):
        return QRect(int(self._x(n,0)), int(self._y(n,0)), int(self._w(n,0.3)),int(self._h(n,1)))
    def _area_yellow(self,n):
        return QRect(int(self._x(n,0.7)), int(self._y(n, 0)), int(self._w(n,0.3)), int(self._h(n, 1.0)))
    def _area(self,n):
        return QRect(int(self._x(n,0)), int(self._y(n, 0)), int(self._w(n,1.0)), int(self._h(n, 1.0)))
    def _x(self,n,v):
        return self.width()*(v)
    def _y(self,n,v):
        return self.height()/self.MAX_PLAYER*(n+v)
    def _w(self,n,v):
        return self.width()*(v)
    def _h(self,n,v):
        return self.height()/self.MAX_PLAYER*(v)
    @pyqtSlot(int,float,float,float,float,bool,bool,float,bool,float,float,float,bool,bool)
    def updateCommandParams(self,robotID,velX,velY,velR,ctrl,mode,shoot,power,use_imu,angle,dribble_velocity,dribble_torque_ff,control_all,control_all_which_team):
        self.cmdSender.updateCommandParams(robotID,velX,velY,velR,ctrl,mode,shoot,power,use_imu,angle,dribble_velocity,dribble_torque_ff)
        self.control_all = control_all
        self.control_all_which_team = control_all_which_team
        
        if (self.control_all == False and self.control_all_finish == True):
            self.control_all_finish = False
            self.infoReceiver.selected.clear()
        
        if (self.control_all_finish != True and self.control_all == True):
            self.control_all_team()
             
    def control_all_team(self):
        self.pointtopointRecv.receive_flag = False
        self.infoReceiver.selected.clear()
        if (self.control_all_which_team == False):
            for info in self.infoReceiver.info.values():
                index = info.robot_id+(info.team-1)*16
                if index < 16:
                    self.infoReceiver.selected[index] = info
                    self.drawSignal.emit(index,info)
        else:
            for info in self.infoReceiver.info.values():
                index = info.robot_id+(info.team-1)*16
                if index >= 16:
                    self.infoReceiver.selected[index] = info
                    self.drawSignal.emit(index,info)
        self.control_all_finish = True
    
    @pyqtSlot()
    def sendCommand(self):
        
        global needPlot
        global plotInitFinish
        
        if needPlot and plotInitFinish:
        
            global length
            global plotData
            global plotDataList
            global plotDataNum
            
            for index in range(plotDataNum):
                plotDataList[index].append(plotData[index])
            
            if slide == True:
                length += 1    
                       
        self.cmdSender.sendCommand(self.infoReceiver)
        
        

    def paint_signal(self,info):
        if self.ready and self.painter.isActive():
            self.statusSingnal.emit(info)

    def _live_plot_value(self, field_key: str, info: zss.Robot_Status) -> float:
        if field_key == "odom_vx":
            return float(info.real_pose[1]) if len(info.real_pose) > 1 else 0.0
        if field_key == "odom_vy":
            return float(info.real_pose[3]) if len(info.real_pose) > 3 else 0.0
        if field_key == "omega_z":
            return float(info.imu_data[6]) if len(info.imu_data) > 6 else 0.0
        if field_key == "angle_z":
            return float(info.imu_data[10]) if len(info.imu_data) > 10 else 0.0
        if field_key.startswith("wheel"):
            try:
                index = int(field_key.replace("wheel", ""))
                return float(info.wheel_encoder[index]) if len(info.wheel_encoder) > index else 0.0
            except Exception:
                return 0.0
        if field_key == "battery":
            return float(info.battery) / 10.0
        if field_key == "capacitance":
            return float(info.capacitance) / 10.0
        return 0.0

    def _append_live_plot_sample(self):
        if self._latest_status is None or not self._live_plot_fields:
            return
        self._live_plot_tick += 1
        max_points = 800
        for field in self._live_plot_fields:
            values = self._live_plot_data.setdefault(field, [])
            values.append(self._live_plot_value(field, self._latest_status))
            if len(values) > max_points:
                del values[:len(values) - max_points]

        for field, curve in self._live_plot_curves.items():
            values = self._live_plot_data.get(field, [])
            start = self._live_plot_tick - len(values) + 1
            curve.setData(list(range(start, start + len(values))), values)

    @pyqtSlot(str)
    def startLivePlot(self, fields_csv):
        fields = [field.strip() for field in str(fields_csv).split(",") if field.strip()]
        if not fields:
            print("[WARN] startLivePlot: no fields selected.")
            return

        self._live_plot_fields = fields
        self._live_plot_data = {field: [] for field in fields}
        self._live_plot_curves = {}
        self._live_plot_tick = 0

        if self._live_plot_win is None:
            self._live_plot_win = pg.GraphicsLayoutWidget(show=True)
            self._live_plot_win.setWindowTitle("zcrazy live plot")
            self._live_plot_win.resize(900, 520)
        else:
            self._live_plot_win.show()
            self._live_plot_win.clear()

        self._live_plot_widget = self._live_plot_win.addPlot()
        self._live_plot_widget.showGrid(x=True, y=True)
        self._live_plot_widget.addLegend()
        for field in fields:
            self._live_plot_curves[field] = self._live_plot_widget.plot(name=field)

        self._live_plot_timer.start(50)

    @pyqtSlot()
    def stopLivePlot(self):
        self._live_plot_timer.stop()

    @pyqtSlot()
    def clearLivePlot(self):
        self._live_plot_data = {field: [] for field in self._live_plot_fields}
        self._live_plot_tick = 0
        for curve in self._live_plot_curves.values():
            curve.setData([], [])

    @pyqtSlot(zss.Robot_Status)
    def paint_single_info(self,info):
        if self.initFinish:
            self._latest_status = info
            # Base panel background by team color.
            if info.team == 1:
                team = "蓝"
                panel_bg = QColor.fromHsl(240, 255, 150)
                row_bg = QColor.fromHsl(240, 255, 235)
            else:
                team = "黄"
                panel_bg = QColor.fromHsl(60, 255, 150)
                row_bg = QColor.fromHsl(60, 255, 235)

            self.painter.setPen(Qt.PenStyle.NoPen)
            self.painter.setBrush(panel_bg)
            for i in range(16):
                # Middle detail panel area (expand to show more data, stop before yellow cards at 0.645)
                self.painter.drawRect(QRectF(self._x(i,0.35), self._y(i,0.0), self._w(i,0.294),self._h(i,1.0)))

            # Use bold SimHei to keep style consistent with broadcast cards.
            status_font = QFont('SimHei', 11)
            # status_font.setBold(True)
            self.painter.setFont(status_font)

            if self.pointtopointRecv.receive_flag:

                battery_v = info.battery / 10.0
                battery_str = "{:.1f}".format(battery_v)
                capacitance_str = "{:.1f}".format(info.capacitance/10.0)
                if info.team ==1:
                    team="蓝"
                else :
                    team="黄"
                angle_z_str="{:.3f}".format(info.imu_data[10])
                angle_y_str = "{:.3f}".format(info.imu_data[9])
                angle_x_str = "{:.3f}".format(info.imu_data[8])
                w_z_str = "{:.3f}".format(info.imu_data[6])
                odom_vx_str = "{:.3f}".format(info.real_pose[1] if len(info.real_pose) > 1 else 0.0)
                odom_vy_str = "{:.3f}".format(info.real_pose[3] if len(info.real_pose) > 3 else 0.0)
                w_x_str = odom_vx_str
                w_y_str = odom_vy_str
                wheel0_str="{:.0f}".format(info.wheel_encoder[0])
                wheel1_str = "{:.0f}".format(info.wheel_encoder[1])
                wheel2_str = "{:.0f}".format(info.wheel_encoder[2])
                wheel3_str = "{:.0f}".format(info.wheel_encoder[3])
                infrared_str = "{:.0f}".format(info.infrared)
                # Draw one rounded label row with subtle shadow and optional highlight color.
                def draw_info_row(idx, content, text_color=QColor(25, 25, 25), bg_color=row_bg):
                    card_rect = QRectF(
                        self._x(idx, 0.353),
                        self._y(idx, 0.04),
                        self._w(idx, 0.292),
                        self._h(idx, 0.9),
                    )

                    # Add edge stroke for better contrast between rows.
                    self.painter.setPen(QColor(110, 120, 130, 150))
                    self.painter.setBrush(bg_color)
                    self.painter.drawRoundedRect(card_rect, 8.0, 8.0)

                    text_rect_shadow = QRectF(
                        card_rect.x() + 1.2,
                        card_rect.y() + 1.2,
                        card_rect.width(),
                        card_rect.height(),
                    )
                    self.painter.setPen(QColor(0, 0, 0, 70))
                    # self.painter.drawText(
                    #     text_rect_shadow,
                    #     Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                    #     "  " + content,
                    # )

                    self.painter.setPen(text_color)
                    self.painter.save()
                    self.painter.setClipRect(card_rect)
                    self.painter.drawText(
                        card_rect,
                        Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter,
                        " " + content,
                    )
                    self.painter.restore()

                rows = [
                    (0, "车号: " + str(info.robot_id), QColor(10, 10, 10), row_bg),
                    (1, "车队: " + str(team), QColor(10, 10, 10), row_bg),
                    (2, "0 号轮速度: " + str(wheel0_str), QColor(10, 10, 10), row_bg),
                    (3, "1 号轮速度: " + str(wheel1_str), QColor(10, 10, 10), row_bg),
                    (4, "2 号轮速度: " + str(wheel2_str), QColor(10, 10, 10), row_bg),
                    (5, "3 号轮速度: " + str(wheel3_str), QColor(10, 10, 10), row_bg),
                    (6, "电容电压/V " + capacitance_str, QColor(10, 10, 10), row_bg),
                    (7, "电池电量/V " + battery_str, QColor(10, 10, 10), row_bg),
                    (8, "红外时间 " + str(infrared_str), QColor(10, 10, 10), row_bg),
                    (9, "X 轴角度 " + str(angle_x_str), QColor(10, 10, 10), row_bg),
                    (10, "Y 轴角度 " + str(angle_y_str), QColor(10, 10, 10), row_bg),
                    (11, "Z 轴角度 " + str(angle_z_str), QColor(10, 10, 10), row_bg),
                    (12, "X 轴角速度 " + w_x_str, QColor(10, 10, 10), row_bg),
                    (13, "Y 轴角速度 " + w_y_str, QColor(10, 10, 10), row_bg),
                    (14, "Z 轴加速度 " + w_z_str, QColor(10, 10, 10), row_bg),
                ]

                rows[12] = (12, "Odom Vx(m/s) " + odom_vx_str, QColor(10, 10, 10), row_bg)
                rows[13] = (13, "Odom Vy(m/s) " + odom_vy_str, QColor(10, 10, 10), row_bg)

                for idx, content, text_color, bg_color in rows:
                    draw_info_row(idx, content, text_color, bg_color)
                
                global ipForward

                draw_info_row(15, "ip: " + ipForward, QColor(10, 10, 10), row_bg)
                
                global plotData
                global plotInitFinish
                global needPlot
                        
                if needPlot and plotInitFinish: 
                    for i in range(len(fdbNeedPlotName)):
                        plotData[i] = eval(fdbNeedPlotName[i])
                            
            self.update()
        
    @pyqtSlot(bool)    
    def car_num(self,only_one):
        self.only_one = only_one

    @pyqtSlot(int)
    def changeTeam(self, team_new):
        if team_new not in (zss.Team.BLUE, zss.Team.YELLOW):
            return

        selected_count = len(self.infoReceiver.selected)
        if selected_count != 1:
            print(f"[WARN] changeTeam requires exactly 1 selected robot, got {selected_count}.")
            return

        old_key, old_info = next(iter(self.infoReceiver.selected.items()))
        robot_id = old_key % 16
        new_robot_id = robot_id

        # If the target team already has the same id, many firmwares will reject team switch.
        # In that case, automatically pick a free id in the target team and request team+id change together.
        conflict = False
        used_ids_in_target_team = set()
        for info in self.infoReceiver.info.values():
            if info.team == team_new:
                used_ids_in_target_team.add(int(info.robot_id))
                if info.robot_id == robot_id and info.ip != old_info.ip:
                    conflict = True

        if conflict:
            free_id = None
            for candidate in range(16):
                if candidate not in used_ids_in_target_team:
                    free_id = candidate
                    break
            if free_id is None:
                print(f"[WARN] changeTeam failed: no free id in target team={team_new}.")
                return
            new_robot_id = free_id
            print(f"[INFO] changeTeam conflict: auto change id {robot_id} -> {new_robot_id} in target team={team_new}.")

        new_key = new_robot_id + (team_new - 1) * 16

        if self._pending_change is not None:
            print("[WARN] Another change is in progress; please wait.")
            return

        self.pointtopointRecv.receive_flag = False
        now_ms = int(datetime.now().timestamp() * 1000)
        self._pending_change = {
            'old_key': old_key,
            'new_key': new_key,
            'ip_last': int(old_info.ip),
            'team': int(team_new),
            'id': int(new_robot_id),
            'started_ms': now_ms,
            'deadline_ms': now_ms + 4000,
        }
        self.cmdSender.changeTeam(team_new)
        # Some firmwares only apply team switch when id is explicitly provided.
        # Sending id together is safe even if unchanged.
        self.cmdSender.changeId(int(new_robot_id))

    @pyqtSlot(int)
    def changeTeamAll(self, team_new):
        """
        Change the team of all currently known robots to `team_new` without changing IDs.
        Rules:
        - If a robot is already in the target team, do nothing.
        - If a robot's ID already exists in the target team, do nothing.
        - Otherwise, switch its team while keeping the same ID.
        Sends repeated change packets directly to each robot's IP for reliability.
        """
        if team_new not in (zss.Team.BLUE, zss.Team.YELLOW):
            return

        infos = list(self.infoReceiver.info.values())
        if not infos:
            print("[WARN] changeTeamAll: no robots known.")
            return

        target_team = int(team_new)
        target_team_ids = {int(info.robot_id) for info in infos if int(info.team) == target_team}
        changed = 0
        skipped_conflict = 0

        for info in infos:
            if int(info.team) == target_team:
                continue
            robot_id = int(info.robot_id)
            if robot_id in target_team_ids:
                skipped_conflict += 1
                continue

            pb = zss.Robot_Command()
            pb.robot_id = robot_id
            pb.need_change_team = True
            pb.team_new = target_team
            pb.need_change_id = True
            pb.id_new = robot_id
            pb.isdebug = True
            data = pb.SerializeToString()
            for _ in range(20):
                try:
                    self.cmdSender.udpSender.send(data, ipForward + "." + format(int(info.ip)), SEND_PORT)
                except Exception as e:
                    print(f"[ERROR] changeTeamAll send failed to {info.ip}: {e}")

            target_team_ids.add(robot_id)
            changed += 1

        if changed == 0 and skipped_conflict == 0:
            print("[INFO] changeTeamAll: no robots needed changes.")
        if skipped_conflict > 0:
            print(f"[INFO] changeTeamAll: skipped {skipped_conflict} robot(s) due to ID conflicts in target team.")


    @pyqtSlot(int)
    def changeId(self, id_new):
        if id_new < 0 or id_new > 15:
            return

        selected_count = len(self.infoReceiver.selected)
        if selected_count != 1:
            print(f"[WARN] changeId requires exactly 1 selected robot, got {selected_count}.")
            return

        old_key, old_info = next(iter(self.infoReceiver.selected.items()))
        team = (old_key // 16) + 1
        new_key = id_new + (team - 1) * 16

        # If a conflict exists, still allow the command (user can resolve duplicates by changing id again).
        for info in self.infoReceiver.info.values():
            if info.team == team and info.robot_id == id_new and info.ip != old_info.ip:
                print(f"[WARN] changeId target may conflict: team={team} id={id_new}.")
                break

        if self._pending_change is not None:
            print("[WARN] Another change is in progress; please wait.")
            return

        self.pointtopointRecv.receive_flag = False
        now_ms = int(datetime.now().timestamp() * 1000)
        self._pending_change = {
            'old_key': old_key,
            'new_key': new_key,
            'ip_last': int(old_info.ip),
            'team': int(team),
            'id': int(id_new),
            'started_ms': now_ms,
            'deadline_ms': now_ms + 4000,
        }
        self.cmdSender.changeId(id_new)

    @pyqtSlot()
    
        
    @pyqtSlot()    
    def plotStart(self):
        # if plotGoal != whichPlotEnum.kNone:
        #     timer.start(10)#多少ms调用一次
        if needPlot:
            timer.start(8)
      
    @pyqtSlot()  
    def plotStop(self):
        # if plotGoal != whichPlotEnum.kNone:
        #     timer.stop()
        if needPlot:
            timer.stop()

    def _trajectory_history_path(self) -> str:
        return os.path.join(os.path.abspath("."), TRAJECTORY_HISTORY_FILE)

    def _read_trajectory_history(self) -> list:
        path = self._trajectory_history_path()
        if not os.path.exists(path):
            return []
        try:
            with open(path, "r", encoding="utf-8") as file:
                data = json.load(file)
            return data if isinstance(data, list) else []
        except Exception as e:
            print(f"[WARN] read trajectory history failed: {e}")
            return []

    def _write_trajectory_history(self, data: list) -> bool:
        try:
            with open(self._trajectory_history_path(), "w", encoding="utf-8") as file:
                json.dump(data, file, ensure_ascii=False, indent=2)
            return True
        except Exception as e:
            print(f"[WARN] write trajectory history failed: {e}")
            return False

    @pyqtSlot(str, result=bool)
    def startTrajectory(self, spec_json):
        return self.cmdSender.startTrajectory(spec_json)

    @pyqtSlot()
    def stopTrajectory(self):
        self.cmdSender.stopTrajectory()

    @pyqtSlot(result=str)
    def trajectoryHistoryJson(self):
        return json.dumps(self._read_trajectory_history(), ensure_ascii=False)

    @pyqtSlot(str, str, result=bool)
    def saveTrajectoryHistory(self, name, spec_json):
        name = str(name).strip()
        if not name:
            name = "trajectory"
        try:
            spec = json.loads(spec_json)
        except Exception as e:
            print(f"[WARN] saveTrajectoryHistory invalid spec: {e}")
            return False

        data = self._read_trajectory_history()
        item = {
            "name": name,
            "spec": spec,
            "saved_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        replaced = False
        for index, old in enumerate(data):
            if old.get("name") == name:
                data[index] = item
                replaced = True
                break
        if not replaced:
            data.append(item)
        return self._write_trajectory_history(data)

    @pyqtSlot()
    def emergencyStop(self):
        self.cmdSender.emergencyStop()
    



top = 0.5
bottom = -0.5
slide = False

def plotCallback():
    
    global length
    global top
    global bottom
    global slide
    global plotData
    global plotDataList
    global historyLength
    global plotDataNum
            
    
    lenMoreThanOne = True
    
    for index in range(plotDataNum):
        lenMoreThanOne =  lenMoreThanOne and (len(plotDataList[index]) > 1)
        
    if lenMoreThanOne:
        for index in range(plotDataNum):
            if plotDataList[index][-1] > top:
                top = plotDataList[index][-1]
            elif plotDataList[index][-1] < bottom:
                bottom = plotDataList[index][-1]
                
    noSlide = True
    
    for index in range(plotDataNum):
        noSlide = noSlide and (len(plotDataList[index])<historyLength)
        
    if noSlide:
        p.setRange(xRange=[0, historyLength+0], yRange=[bottom, top], update=False)
    else:
        p.setRange(xRange=[length, historyLength+length], yRange=[bottom, top], update=False)
        slide = True    
    
    for index in range(plotDataNum):
        curve[index].setData(plotDataList[index])
    
isFdb = True

def is_nested_field_exists(field_path: list[str], message_class) -> bool:
    descriptor = message_class.DESCRIPTOR
    for field_name in field_path:
        if field_name not in descriptor.fields_by_name:
            return False
        field = descriptor.fields_by_name[field_name]
        descriptor = field.message_type  # 进入下一层描述符
    return True

if __name__ == '__main__':
    # AppImage environments may not provide usable GLX/EGL; force software rendering.
    os.environ.setdefault("LIBGL_ALWAYS_SOFTWARE", "1")
    os.environ.setdefault("QT_OPENGL", "software")
    os.environ.setdefault("QT_XCB_GL_INTEGRATION", "none")
    os.environ.setdefault("QSG_RHI_BACKEND", "software")
    os.environ.setdefault("QT_QUICK_BACKEND", "software")
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    qmlRegisterType(InfoViewer, 'ZSS', 1, 0, 'InfoViewer')
    
    needPlotTmp = True
        
    with open(resource_path('zcrazy.txt'),'r') as file:
        for line in file:
            if needPlotTmp and line.strip() != 'true:':
                needPlotTmp = False  
                needPlot = False    
                break             
            else:
                needPlotTmp = False
                needPlot = True
                if line.strip()[0] == "-":
                    isFdb = False
                else:
                    if isFdb:
                        tmp = line.strip().split()
                        tmpNum = ""
                        tmpPath = tmp[0].split(".")
                        if is_nested_field_exists(tmpPath,zss.Robot_Status):
                            for i in tmp:
                                tmpNum = tmpNum+i
                            fdbNeedPlotName.append(fdbPlotForward+tmpNum)
                    else:
                        tmp = line.strip().split()
                        tmpNum = ""
                        tmpPath = tmp[0].split(".")
                        if is_nested_field_exists(tmpPath,zss.Robot_Command):
                            for i in tmp:
                                tmpNum = tmpNum+i
                            refNeedPlotName.append(refPlotForward+tmpNum)
                
                
    print(needPlot)
      
    plotDataNum = len(fdbNeedPlotName) + len(refNeedPlotName)  
    
    print(plotDataNum)
    print(fdbNeedPlotName)
    print(refNeedPlotName)
    
    global plotData
    global plotDataList
    global plotInitFinish
    
    plotData = [0]*plotDataNum
    plotDataList = [[] for _ in range(plotDataNum)]
    plotInitFinish = True
                                
    if needPlot and plotInitFinish:
        
        curve = []
        
        win = pg.GraphicsLayoutWidget(show=True)#建立窗口
        win.setWindowTitle(u'zcrazy')
        win.resize(800, 500)#小窗口大小

        historyLength = 100#横坐标长度
        p = win.addPlot()#把图p加入到窗口中
        p.showGrid(x=True, y=True)#把X和Y的表格打开    
        
           
        for index in range(plotDataNum):
            curve.append(p.plot())
        
        
        length=0
        timer = pg.QtCore.QTimer()
        timer.timeout.connect(plotCallback)#定时调用plotCallback函数
    
    
    # 创建 InfoViewer 实例
    # 连接退出信号
    engine.quit.connect(app.quit)
    # 加载QML文件
    try:
        engine.load(resource_path('main.qml'))
    except Exception as e:
        print("Failed to load QML:", e)
        sys.exit(1)
    # 执行应用程序
    res = app.exec()
    # 清理资源
    del engine
    sys.exit(res)
    # udpSender = UdpSender()
    # while True:
    #     time.sleep(1)
