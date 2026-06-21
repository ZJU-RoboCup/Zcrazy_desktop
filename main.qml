import QtQuick
import QtQuick.Controls
import QtQuick.Window
import ZSS as ZSS
ApplicationWindow {
    visible: true
    width: Math.min(1550, Screen.desktopAvailableWidth - 40)
    height: Math.min(760, Screen.desktopAvailableHeight - 80)
    x: Math.max(0, (Screen.desktopAvailableWidth - width) / 2)
    y: Math.max(0, (Screen.desktopAvailableHeight - height) / 2)
    title: "Zrazy"
    Timer{
        id:timer;
        interval:8;
        running:false;
        repeat:true;
        onTriggered: {
            
            // if(switchControl.checked)
            //     crazyShow.updateFromGamepad();
            // ui.cmdUI.updateCommand();//调用serial.updateCommandParams()
            infoViewer.sendCommand();//把数据发出去
        }
    }

    onClosing: {
        infoViewer.close();
    }
    Rectangle{
        width:parent.width-infoViewerRect.width
        height:parent.height
        anchors.left:parent.left
        color: "transparent"

        focus: true
        UI{
            cmdSender:infoViewer
        }
    }
    Rectangle{
        id:infoViewerRect
        width: Math.max(520, Math.min(650, parent.width * 0.36))
        height:parent.height
        anchors.right:parent.right
        color:"#333333"
        ZSS.InfoViewer{
            id: infoViewer
            anchors.fill:parent
            onWidthChanged: this.resize(width,height)
            onHeightChanged: this.resize(width,height)
        }
    }

}
