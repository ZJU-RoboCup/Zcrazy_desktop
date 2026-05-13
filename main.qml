import QtQuick
import QtQuick.Controls
import ZSS as ZSS
ApplicationWindow {
    visible: true
    width: 1550
    height: 760
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
        width:650
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