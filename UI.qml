import QtQuick
import QtQuick.Controls

Rectangle{
    width:parent.width;
    anchors.top: parent.top;
    anchors.bottom: parent.bottom;
    color:"transparent";
    id:radioRectangle;
    property var cmdSender;

    //下面大的Box
    ZGroupBox{
        title : qsTr("Control Panel");
        width:parent.width - 15;
        anchors.top:parent.top;
        anchors.topMargin:8;
        // anchors.bottom:parent.bottom;
        // anchors.bottomMargin:8;
        anchors.horizontalCenter: parent.horizontalCenter;
        id : groupBox2;
        Grid{
            id : crazyShow;
            columns: 6;//6列
            verticalItemAlignment: Grid.AlignVCenter;
            horizontalItemAlignment: Grid.AlignLeft;
            anchors.horizontalCenter: parent.horizontalCenter;
            columnSpacing: 10;
            rowSpacing: 5;
            property int robotID : 0;//Robot
            property int velX : 0;//Vx
            property int velY : 0;//Vy
            property int velR : 0;//Vr
            property bool shoot : false;//Shoot
            property bool dribble : false;//Dribb
            property bool rush : false;//Rush

            property bool test_dribble : false;
            // property int test_drib_speed : 150;
            property int test_drib_level : 30;
            property int test_drib_vr : 0;
            property int test_drib_vr_step : 2;

            property int velXStep : 200;//VxStep
            property int velYStep : 200;//VyStep
            property int velRStep : 1;//VrStep
            property int angleStep : 10;
            property bool mode : false;//KickMode
            property int dribbleLevel : 10;//DribLevel
            property int dribbleVelocity : -50;//DribVel [turns/s]
            property int dribbleTorqueMilli : 100;//DribTorque [mNm]
            property double paramVxAcc : 7.0;
            property double paramVyAcc : 7.0;
            property double paramVxJerk : 1000.0;
            property double paramVyJerk : 1000.0;
            property double paramVxDec : 10.0;
            property double paramVyDec : 10.0;
            property double paramYawVel : 25.0;
            property double paramYawAcc : 40.0;
            property double paramYawJerk : 200.0;
            property int rushSpeed : 200;//RushSpeed

            property int power : 20;//KickPower

            property int m_VELR : 80;//MaxVelR [rad/s]
            property int m_VEL : 8000//MaxVel (mm/s)
            property int velocityRMax : m_VELR;//MaxVelR [rad/s]
            property int velocityMax : m_VEL;//最大速度
            property int m_angle :180;
            property int angleMax : m_angle;//最大角度

            property int dribbleMaxLevel : 30;//吸球最大等级
            property int dribbleVelocityMax : 200;
            property int dribbleTorqueMilliMax : 1000;
            property double dribble_test_L : 98.72/1000.0;
            property double dribble_test_cos : 0.9725;
            property double dribble_test_sin : 0.2330;
            property int kickPowerMax: 300;//最大踢球力量[50us]
            // UI uses mm/s and rad/s; convert to m/s and rad/s for backend.
            property double r_VEL_RATIO : 0.001;
            property double r_VELR_RATIO : 1.0;
            property double r_DRIBBLE_RATIO : 0.1;
            property double r_KICK_RATIO : 50;
            property int itemWidth : (parent.width-columnSpacing*(columns))/columns;
            property string textV : qsTr("(mm/s)");
            property string textW : qsTr("(rad/s)");
            property string textP : qsTr("(50us)");

            property bool use_imu : false;
            property double angle : 0;

            property bool only_one : true;
            property int team_new : 1;
            property int id_new : 0;
            property bool control_all : false;
            property bool control_all_which_team : false; // 0 for blue,1 for yellow

            ZText{ text:qsTr("Robot")  }
            //最多12辆车
            SpinBox{ editable:true; from:0; to:15; value:parent.robotID; width:parent.itemWidth
                onValueModified:{parent.robotID = value}}
            ZText{ text:"Stop" }
            //有用吗？
            Button{ text:qsTr("[Space]") ;width:parent.itemWidth
            }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:qsTr("Vx [W/S]")  }
            //Vx:(-m_VEL, m_VEL)
            SpinBox{ editable:true; from:-crazyShow.m_VEL; to:crazyShow.m_VEL; value:parent.velX;width:parent.itemWidth
                onValueModified:{parent.velX = value;}}
            ZText{ text:qsTr("VxStep "+parent.textV)  }
            //VxStep:(1, m_VEL)
            SpinBox{ editable:true; from:1; to:crazyShow.m_VEL; value:parent.velXStep;width:parent.itemWidth;
                onValueModified:{parent.velXStep = value;}}
            ZText{ text:qsTr("MaxVel "+parent.textV)  }
            //MaxVel:(1, velocityMax)
            SpinBox{ editable:true; from:1; to:crazyShow.velocityMax; value:parent.m_VEL;width:parent.itemWidth
                onValueModified:{parent.m_VEL = value;}}
            ZText{ text:qsTr("Vy [A/D]") }
            //Vy:(-m_VEL, m_VEL)
            SpinBox{ editable:true; from:-crazyShow.m_VEL; to:crazyShow.m_VEL; value:-parent.velY;width:parent.itemWidth
                onValueModified:{parent.velY = -value;}}
            ZText{ text:qsTr("VyStep "+parent.textV)  }
            //VyStep:(1, m_VEL)
            SpinBox{ editable:true; from:1; to:crazyShow.m_VEL; value:parent.velYStep;width:parent.itemWidth
                onValueModified:{parent.velYStep = value;}}
            ZText{ text:" " }
            ZText{ text:" " }

            //Vr:(-m_VEL, m_VEL)
            ZText{ text:qsTr(((parent.use_imu)?("angle"):("Vr")) +" [Left/Right]")  }
            SpinBox{ editable:true; from:(parent.use_imu)?(-crazyShow.m_angle):(-crazyShow.m_VELR); to:(parent.use_imu)?(crazyShow.m_angle):(crazyShow.m_VELR); value:(parent.use_imu)?(parent.angle):(parent.velR);width:parent.itemWidth
                onValueModified:{
                    if(parent.use_imu)
                    {   
                        parent.angle = value;
                    }
                    else
                    {
                        parent.velR = value;
                    }
                    }}
            
            //VrStep:(1, m_VELR)
            ZText{ text:qsTr((parent.use_imu)?("angleStep"):("VrStep "+parent.textW))  }
            SpinBox{ editable:true; from:1; to:(parent.use_imu)?(crazyShow.m_angle):(crazyShow.m_VELR); value:(parent.use_imu)?(parent.angleStep):(parent.velRStep);width:parent.itemWidth
                onValueModified:{
                    if((parent.use_imu))
                    {
                        parent.angleStep = value;
                    }
                    else
                    {
                        parent.velRStep = value;
                    }
                    }}
            
            //MaxVelR:(1, velocityRMax)
            ZText{ text:qsTr((parent.use_imu)?("MaxAngle"):("MaxVelR "+parent.textW))  }
            SpinBox{ editable:true; from:1; to:((parent.use_imu)?(crazyShow.angleMax):(crazyShow.velocityRMax)); value:((parent.use_imu)?(parent.m_angle):(parent.m_VELR));width:parent.itemWidth
                onValueModified:{
                    if((parent.use_imu))
                    {
                        parent.m_angle = value;
                    }
                    else
                    {
                        parent.m_VELR = value;
                    }
                    }}

            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:qsTr("Shoot [E]") }
            Button{ text:(parent.shoot? qsTr("true") : qsTr("false")) ;width:parent.itemWidth
                background: Rectangle {
                    color: crazyShow.shoot ? "#e53935" : "#f2f2f2"
                    border.color: "#a8a8a8"
                    radius: 2
                }
                onClicked: { parent.shoot = !parent.shoot; }
            }

            ZText{ text:qsTr("KickMode [Up]")  }
            Button{ text:(parent.mode?qsTr("chip"):qsTr("flat")) ;width:parent.itemWidth
                onClicked: { parent.mode = !parent.mode }
            }
            ZText{ text:qsTr("KickPower "+parent.textP)  }
            //KickPower:(1, kickPowerMax)
            SpinBox{ editable:true; from:0; to:parent.kickPowerMax; value:parent.power;width:parent.itemWidth
                onValueModified:{parent.power = value;}}
            ZText{ text:qsTr("Dribb [Q]")  }
            Button{ text:(parent.dribble ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth
                onClicked: { parent.dribble = !parent.dribble; }
            }
            ZText{ text:qsTr("DribLevel")  }
            //DribLevel:(0, dribbleMaxLevel)
            SpinBox{ editable:true; from:0; to:crazyShow.dribbleMaxLevel; value:parent.dribbleLevel;width:parent.itemWidth
                onValueModified:{parent.dribbleLevel = value;}}
            ZText{ text:qsTr("Parameter")  }
            Button{ text:qsTr("Open") ;width:parent.itemWidth
                onClicked: {
                    parameterPopup.open();
                }
            }
            ZText{ text:qsTr("Rush [G]")  }
            Button{ text:(parent.rush ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth;
                onClicked: {
                    parent.rush = !parent.rush;
                    crazyShow.updateRush();
                }
            }
            ZText{ text:qsTr("RushSpeed "+parent.textV)  }
            //RushSpeed:(0, m_VEL)
            SpinBox{ editable:true; from:0; to:crazyShow.m_VEL; value:parent.rushSpeed;width:parent.itemWidth
                onValueModified:{parent.rushSpeed = value;}}
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:qsTr("test_dribble [B]")  }
            Button{ text:(parent.test_dribble ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth;
                onClicked: {
                    parent.test_dribble = !parent.test_dribble;
                    crazyShow.action_drib_test();
                }
            }
            // ZText{ text:" " }
            // ZText{ text:" " }
            // ZText{ text:" " }
            // ZText{ text:" " }
            // ZText{ text:qsTr("test_DribLevel")  }
            // //DribLevel:(0, dribbleMaxLevel)
            // SpinBox{ editable:true; from:0; to:crazyShow.dribbleMaxLevel; value:parent.test_drib_level;width:parent.itemWidth
            //     onValueModified:{parent.test_drib_level = value;}}
            // ZText{ text:qsTr("testSpeed "+parent.textV)  }
            // //RushSpeed:(0, m_VEL)
            // SpinBox{ editable:true; from:0; to:crazyShow.m_VEL; value:parent.test_drib_speed;width:parent.itemWidth
            //     onValueModified:{parent.test_drib_speed = value;}}
            ZText{ text:qsTr("testVr [J K]"+parent.textW)  }
            //RushSpeed:(0, m_VEL)
            SpinBox{ editable:true; from:-crazyShow.m_VELR; to:crazyShow.m_VELR; value:parent.test_drib_vr;width:parent.itemWidth
                onValueModified:{parent.test_drib_vr = value;}}
            ZText{ text:qsTr("testVrStep "+parent.textW)  }
            //RushSpeed:(0, m_VEL)
            SpinBox{ editable:true; from:0; to:crazyShow.m_VELR; value:parent.test_drib_vr_step;width:parent.itemWidth
                onValueModified:{parent.test_drib_vr_step = value;}}


            ZText{ text:qsTr("use_imu [I]")  }
            Button{ text:(parent.use_imu ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth;
                onClicked: {
                    parent.use_imu = !parent.use_imu;
                }
            }

            ZText{ text:qsTr("only one [P]")  }
            Button{ text:(parent.only_one ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth;
                onClicked: {
                    parent.only_one = !parent.only_one;
                }
            }

            ZText{ text:qsTr("control all [N]")  }
            Button{ text:(parent.control_all ? qsTr("true") : qsTr("false")) ;width:parent.itemWidth
                onClicked: { 
                    parent.control_all = !parent.control_all; 
                    }
            }

            ZText{ text:qsTr("control team [M]")  }
            Button{ text:qsTr((parent.control_all_which_team)?"yellow":"blue") ;width:parent.itemWidth
                onClicked: { 
                    parent.control_all_which_team = !parent.control_all_which_team; 
                    }
            }

            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }
            ZText{ text:" " }

            ZText{ text:qsTr("team new")  }
            SpinBox{ editable:true; from:1; to:2; value:parent.team_new; width:parent.itemWidth
                onValueModified:{parent.team_new = value;}}

            ZText{ text:qsTr("id new")  }
            SpinBox{ editable:true; from:0; to:15; value:parent.id_new; width:parent.itemWidth
                onValueModified:{parent.id_new = value;}}

            Button{ text:qsTr("change team") ;width:parent.itemWidth
                onClicked: {
                    radioRectangle.cmdSender.changeTeam(parent.team_new);
                }
            }

            Button{ text:qsTr("change id") ;width:parent.itemWidth
                onClicked: {
                    radioRectangle.cmdSender.changeId(parent.id_new);
                }
            }

            Button{ text:qsTr("all -> blue") ;width:parent.itemWidth
                onClicked: {
                    // change all known robots to blue (team 1)
                    radioRectangle.cmdSender.changeTeamAll(1);
                }
            }

            Button{ text:qsTr("all -> yellow") ;width:parent.itemWidth
                onClicked: {
                    // change all known robots to yellow (team 2)
                    radioRectangle.cmdSender.changeTeamAll(2);
                }
            }

            //角度pid
            ZText{ text:qsTr("Trajectory") }
            Button{ text:qsTr("Open") ;width:parent.itemWidth
                onClicked: {
                    trajectoryPopup.open();
                }
            }
            ZText{ text:qsTr("Plot") }
            Button{ text:qsTr("Open") ;width:parent.itemWidth
                onClicked: {
                    livePlotPopup.open();
                }
            }
            ZText{ text:" " }
            ZText{ text:" " }

            //ZText{ text:qsTr("testSpeed "+parent.textV)  }

            //键盘响应实现
            Keys.onPressed: (event) => {getFocus(event);}
            function getFocus(event){
                switch(event.key){
                case Qt.Key_Enter:
                case Qt.Key_Return:
                case Qt.Key_Escape:
                    crazyShow.focus = true;
                    break;
                default:
                    event.accepted = false;
                    return false;
                }
                event.accepted = true;
            }
            function updateStop(){
                // emergency stop: bypass trapezoidal ramp and send zero immediately
                radioRectangle.cmdSender.emergencyStop();
                crazyShow.velX = 0;
                crazyShow.velY = 0;
                crazyShow.velR = 0;
                crazyShow.shoot = false;
                crazyShow.dribble = false;
                crazyShow.rush = false;
                // crazyShow.use_imu = false;
                // crazyShow.use_vision = false;
            }
            function updateRush(){
                if(crazyShow.rush){
                    crazyShow.velX = crazyShow.rushSpeed;
                    crazyShow.velY = 0;
                    crazyShow.velR = 0;
                    crazyShow.shoot = true;
                    crazyShow.dribble = false;
                }else{
                    crazyShow.updateStop();
                }
            }

            function action_drib_test(){
                if(crazyShow.test_dribble){
                   
                    // crazyShow.test_drib_speed = crazyShow.test_drib_vr/0.085
                // velR in rad/s, L in meters -> m/s; convert to mm/s for UI
                crazyShow.velY = -crazyShow.velR*crazyShow.dribble_test_L*crazyShow.dribble_test_cos*1000;
                // if(crazyShow.velR > 0)
                // {
                //     crazyShow.velX = -crazyShow.velR*crazyShow.dribble_test_L*crazyShow.dribble_test_sin;
                // }

                // if(crazyShow.velR < 0)
                // {
                //     crazyShow.velX = -crazyShow.velR*crazyShow.dribble_test_L*crazyShow.dribble_test_sin;
                // }
                
                // crazyShow.velR = crazyShow.test_drib_vr;
                // crazyShow.dribble = true;
                crazyShow.dribbleLevel =crazyShow.test_drib_level;
                }else{
                        crazyShow.updateStop();
                    }

            }
            function handleKeyboardEvent(e){
                switch(e){
                case 'U':{crazyShow.mode = !crazyShow.mode;break;}
                case 'b':{crazyShow.test_dribble = !crazyShow.test_dribble;
                    break;}
                case 'a':{crazyShow.velY = crazyShow.limitVel(crazyShow.velY+crazyShow.velYStep,-crazyShow.m_VEL,crazyShow.m_VEL);
                    break;}
                case 'd':{crazyShow.velY = crazyShow.limitVel(crazyShow.velY-crazyShow.velYStep,-crazyShow.m_VEL,crazyShow.m_VEL);
                    break;}
                case 'j':{crazyShow.velR = crazyShow.limitVel(crazyShow.velR-crazyShow.test_drib_vr_step,-crazyShow.m_VELR,crazyShow.m_VELR);
                    action_drib_test();
                    break;}
                case 'k':{crazyShow.velR = crazyShow.limitVel(crazyShow.velR+crazyShow.test_drib_vr_step,-crazyShow.m_VELR,crazyShow.m_VELR);
                    action_drib_test();
                    break;}
                case 'w':{crazyShow.velX = crazyShow.limitVel(crazyShow.velX+crazyShow.velXStep,-crazyShow.m_VEL,crazyShow.m_VEL);
                    break;}
                case 's':{crazyShow.velX = crazyShow.limitVel(crazyShow.velX-crazyShow.velXStep,-crazyShow.m_VEL,crazyShow.m_VEL);
                    break;}
                case 'S':{crazyShow.velX = crazyShow.limitVel(crazyShow.velX-crazyShow.velXStep,-crazyShow.m_VEL,crazyShow.m_VEL);
                    break;}
                case 'SPACE':{crazyShow.updateStop();
                    break;}
                case 'q':{crazyShow.dribble = !crazyShow.dribble;
                    break;}
                case 'e':{crazyShow.shoot = !crazyShow.shoot;
                    break;}
                case 'L':{
                    if(crazyShow.use_imu)
                    {
                        var newAngle = crazyShow.angle + crazyShow.angleStep;
                        if (newAngle > crazyShow.m_angle)
                        {
                            newAngle = newAngle - 2 * crazyShow.m_angle;
                        }
                        crazyShow.angle = newAngle;
                        // crazyShow.angle = crazyShow.limitVel(crazyShow.angle+crazyShow.angleStep,-crazyShow.m_angle,crazyShow.m_angle);
                    }
                    else
                    {
                        crazyShow.velR = crazyShow.limitVel(crazyShow.velR+crazyShow.velRStep,-crazyShow.m_VELR,crazyShow.m_VELR);
                    }
                    
                    break;}
                case 'R':{
                    if(crazyShow.use_imu)
                    {
                        var newAngle = crazyShow.angle - crazyShow.angleStep;
                        if (newAngle < -crazyShow.m_angle)
                        {
                            newAngle = newAngle + 2 * crazyShow.m_angle;
                        }
                        crazyShow.angle = newAngle;
                        // crazyShow.angle = crazyShow.limitVel(crazyShow.angle+crazyShow.angleStep,-crazyShow.m_angle,crazyShow.m_angle);
                    }
                    else
                    {
                        crazyShow.velR = crazyShow.limitVel(crazyShow.velR-crazyShow.velRStep,-crazyShow.m_VELR,crazyShow.m_VELR);
                    }
                    break;}
                case 'S':{crazyShow.updateStop();
                    break;}
                case 'g':{crazyShow.rush = !crazyShow.rush;
                    updateRush();
                    break;}
                case 'i':{
                    crazyShow.use_imu = !crazyShow.use_imu;
                    break;
                }
                case 'p':{
                    crazyShow.only_one = !crazyShow.only_one;
                    infoViewer.car_num(only_one)
                    break;
                }
                case 'N':{
                    crazyShow.control_all = !crazyShow.control_all;
                    break;
                }
                case 'M':{
                    crazyShow.control_all_which_team = !crazyShow.control_all_which_team;
                    break;
                }
                case '!':{
                    break;
                }

                default:
                    return false;
                }
                updateCommand();
            }
            function updateCommand(){
                // updateCommandParams(int robotID,double velX,double velY,double velR,double ctrl,bool mode,bool shoot,double power)
                // cmdSender.updateCommandParams(crazyShow.robotID,crazyShow.velX,crazyShow.velY,crazyShow.velR,crazyShow.dribble?crazyShow.dribbleLevel:0,crazyShow.mode,crazyShow.shoot,crazyShow.power);
                cmdSender.updateCommandParams(crazyShow.robotID,
                    crazyShow.velX*crazyShow.r_VEL_RATIO,
                    crazyShow.velY*crazyShow.r_VEL_RATIO,
                    crazyShow.velR*crazyShow.r_VELR_RATIO,
                    (crazyShow.dribble?crazyShow.dribbleLevel:0)*crazyShow.r_DRIBBLE_RATIO,
                    crazyShow.mode,
                    crazyShow.shoot,
                    crazyShow.power*crazyShow.r_KICK_RATIO,
                    crazyShow.use_imu,
                    crazyShow.angle,
                    crazyShow.dribbleVelocity,
                    crazyShow.dribbleTorqueMilli / 1000.0,
                    crazyShow.control_all,
                    crazyShow.control_all_which_team
                );
            }
            function updateFromGamepad(){
                crazyShow.velX = -parseInt(gamepad.axisLeftY*10)/10.0*crazyShow.m_VEL;
                crazyShow.velY = parseInt(gamepad.axisLeftX*10)/10.0*crazyShow.m_VEL;
                crazyShow.velR = parseInt(gamepad.axisRightX*10)/10.0*crazyShow.m_VELR*0.3;
                if(gamepad.buttonX > 0){
                    crazyShow.power = parseInt(gamepad.buttonL2*10)/10.0*crazyShow.kickPowerMax;
                    crazyShow.mode = true;
                    crazyShow.shoot = gamepad.buttonX;
                }
                else if(gamepad.buttonY > 0){
                    crazyShow.power = parseInt(gamepad.buttonL2*10)/10.0*crazyShow.kickPowerMax;
                    crazyShow.mode = false;
                    crazyShow.shoot = gamepad.buttonY;

                }
                else{
                    crazyShow.shoot = 0;
                }

                if(gamepad.buttonR2 > 0){
                    crazyShow.dribbleLevel =  parseInt(gamepad.buttonR2*10)/10.0*crazyShow.dribbleMaxLevel;
                    crazyShow.dribble = true ;
                }
                else{
                    crazyShow.dribble = false ;
                }

                console.log(velX,velY);
            }
            function limitVel(vel,minValue,maxValue){
                if(vel>maxValue) return maxValue;
                if(vel<minValue) return minValue;
                return vel;
            }
            Shortcut{
                sequence:"G";
                onActivated:crazyShow.handleKeyboardEvent('g');
            }
            Shortcut{
                sequence:"A";
                onActivated:crazyShow.handleKeyboardEvent('a');
            }
            Shortcut{
                sequence:"Up";
                onActivated:crazyShow.handleKeyboardEvent('U');
            }
            Shortcut{
                sequence:"D"
                onActivated:crazyShow.handleKeyboardEvent('d');
            }
            Shortcut{
                sequence:"W"
                onActivated:crazyShow.handleKeyboardEvent('w');
            }
            Shortcut{
                sequence:"S"
                onActivated:crazyShow.handleKeyboardEvent('s');
            }
            Shortcut{
                sequence:"Q"
                onActivated:crazyShow.handleKeyboardEvent('q');
            }
            Shortcut{
                sequence:"E"
                onActivated:crazyShow.handleKeyboardEvent('e');
            }
            Shortcut{
                sequence:"Left"
                onActivated:crazyShow.handleKeyboardEvent('L');
            }
            Shortcut{
                sequence:"Right"
                onActivated:crazyShow.handleKeyboardEvent('R');
            }
            Shortcut{
                sequence:"Space"
                onActivated:crazyShow.handleKeyboardEvent('SPACE');
            }
            Shortcut{
                sequence:"B"
                onActivated:crazyShow.handleKeyboardEvent('b');
            }
            Shortcut{
                sequence:"I"
                onActivated:crazyShow.handleKeyboardEvent('i');
            }
            Shortcut{
                sequence:"P"
                onActivated:crazyShow.handleKeyboardEvent('p');
            }
            Shortcut{
                sequence:"N"
                onActivated:crazyShow.handleKeyboardEvent('N');
            }
            Shortcut{
                sequence:"M"
                onActivated:crazyShow.handleKeyboardEvent('M');
            }
            Shortcut{
                sequence:"J"
                onActivated:crazyShow.handleKeyboardEvent('j');
            }
            Shortcut{
                sequence:"K"
                onActivated:crazyShow.handleKeyboardEvent('k');
            }
            
        }
    }
    //最下面的Start按钮
    Popup {
        id: parameterPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.max(20, (radioRectangle.width - width) / 2)
        y: 56
        width: Math.min(radioRectangle.width - 40, 900)
        height: Math.min(radioRectangle.height - 70, 640)
        padding: 0
        property string applyStatusValue: ""

        function formatParam(value, digits) {
            var numberValue = Number(value);
            if (!isFinite(numberValue)) {
                return "--";
            }
            return numberValue.toFixed(digits);
        }

        function scaledText(value, scale, digits, locale) {
            return Number(value / scale).toLocaleString(locale, "f", digits);
        }

        function scaledValue(text, scale, locale) {
            return Math.round(Number.fromLocaleString(locale, text) * scale);
        }

        function applyParameterLimits() {
            radioRectangle.cmdSender.updateParameterLimits(
                crazyShow.paramVxAcc,
                crazyShow.paramVyAcc,
                crazyShow.paramVxJerk,
                crazyShow.paramVyJerk,
                crazyShow.paramVxDec,
                crazyShow.paramVyDec,
                crazyShow.paramYawVel,
                crazyShow.paramYawAcc,
                crazyShow.paramYawJerk
            );
            applyStatusValue = "Applied";
        }

        function refreshParameterFeedback() {
            var params = {};
            try {
                params = JSON.parse(radioRectangle.cmdSender.parameterSummaryJson());
            } catch (error) {
                params = {};
            }
            paramVxAcc.text = formatParam(params.vx_acc, 3);
            paramVyAcc.text = formatParam(params.vy_acc, 3);
            paramVxJerk.text = formatParam(params.vx_jerk, 3);
            paramVyJerk.text = formatParam(params.vy_jerk, 3);
            paramVxDec.text = formatParam(params.vx_dec, 3);
            paramVyDec.text = formatParam(params.vy_dec, 3);
            paramYawVel.text = formatParam(params.yaw_vel, 3);
            paramYawAcc.text = formatParam(params.yaw_acc, 3);
            paramYawJerk.text = formatParam(params.yaw_jerk, 3);
        }

        onOpened: refreshParameterFeedback()

        Timer {
            interval: 200
            running: parameterPopup.visible
            repeat: true
            onTriggered: parameterPopup.refreshParameterFeedback()
        }

        background: Rectangle {
            color: "#f6f6f6"
            border.color: "#9a9a9a"
            radius: 6
        }

        contentItem: Rectangle {
            color: "transparent"
            ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: parameterPopup.width

                Item {
                    width: parameterPopup.width
                    height: parameterColumn.height + 28

            Column {
                id: parameterColumn
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 12

                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: qsTr("Parameter"); font.pixelSize: 22; font.bold: true; width: parent.width - 90 }
                    Button { text: qsTr("Close"); width: 80; onClicked: parameterPopup.close() }
                }

                Grid {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 8
                    width: parent.width

                    Text { text: qsTr("DribVel (turn/s)"); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter; height: 34; width: 230 }
                    SpinBox {
                        editable: true
                        from: -crazyShow.dribbleVelocityMax
                        to: crazyShow.dribbleVelocityMax
                        value: crazyShow.dribbleVelocity
                        width: 180
                        onValueModified: { crazyShow.dribbleVelocity = value; }
                    }

                    Text { text: qsTr("DribTorque (mNm)"); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter; height: 34; width: 230 }
                    SpinBox {
                        editable: true
                        from: -crazyShow.dribbleTorqueMilliMax
                        to: crazyShow.dribbleTorqueMilliMax
                        value: crazyShow.dribbleTorqueMilli
                        width: 180
                        onValueModified: { crazyShow.dribbleTorqueMilli = value; }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#c9c9c9" }

                Text { text: qsTr("Motion Limit Command"); font.pixelSize: 16; font.bold: true; width: parent.width }

                Grid {
                    columns: 4
                    columnSpacing: 12
                    rowSpacing: 8
                    width: parent.width

                    Text { text: qsTr("Vx Acc(m/s^2)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramVxAcc * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVxAcc = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }
                    Text { text: qsTr("Vy Acc(m/s^2)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramVyAcc * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVyAcc = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }

                    Text { text: qsTr("Vx Jerk(m/s^3)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 2000000; value: Math.round(crazyShow.paramVxJerk * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVxJerk = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }
                    Text { text: qsTr("Vy Jerk(m/s^3)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 2000000; value: Math.round(crazyShow.paramVyJerk * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVyJerk = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }

                    Text { text: qsTr("Vx Dec(m/s^2)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramVxDec * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVxDec = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }
                    Text { text: qsTr("Vy Dec(m/s^2)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramVyDec * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramVyDec = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }

                    Text { text: qsTr("Yaw Vel(rad/s)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramYawVel * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramYawVel = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }
                    Text { text: qsTr("Yaw Acc(rad/s^2)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 50000; value: Math.round(crazyShow.paramYawAcc * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramYawAcc = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }

                    Text { text: qsTr("Yaw Jerk(rad/s^3)"); font.pixelSize: 15; width: 170; height: 34; verticalAlignment: Text.AlignVCenter }
                    SpinBox {
                        editable: true; from: 0; to: 1000000; value: Math.round(crazyShow.paramYawJerk * 1000); width: 110
                        textFromValue: function(value, locale) { return parameterPopup.scaledText(value, 1000, 3, locale); }
                        valueFromText: function(text, locale) { return parameterPopup.scaledValue(text, 1000, locale); }
                        onValueModified: { crazyShow.paramYawJerk = value / 1000.0; parameterPopup.applyStatusValue = ""; }
                    }
                    Row {
                        width: 292
                        height: 34
                        spacing: 10
                        Button { text: qsTr("Apply"); width: 110; onClicked: parameterPopup.applyParameterLimits() }
                        Text { text: parameterPopup.applyStatusValue; font.pixelSize: 15; height: 34; verticalAlignment: Text.AlignVCenter }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#c9c9c9" }

                Text { text: qsTr("Motion Limit Feedback"); font.pixelSize: 16; font.bold: true; width: parent.width }

                Grid {
                    columns: 4
                    columnSpacing: 12
                    rowSpacing: 8
                    width: parent.width

                    Text { text: qsTr("Vx Acc(m/s^2)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVxAcc; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { text: qsTr("Vy Acc(m/s^2)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVyAcc; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }

                    Text { text: qsTr("Vx Jerk(m/s^3)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVxJerk; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { text: qsTr("Vy Jerk(m/s^3)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVyJerk; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }

                    Text { text: qsTr("Vx Dec(m/s^2)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVxDec; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { text: qsTr("Vy Dec(m/s^2)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramVyDec; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }

                    Text { text: qsTr("Yaw Vel(rad/s)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramYawVel; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { text: qsTr("Yaw Acc(rad/s^2)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramYawAcc; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }

                    Text { text: qsTr("Yaw Jerk(rad/s^3)"); font.pixelSize: 15; width: 170; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { id: paramYawJerk; text: "0.000"; font.pixelSize: 15; font.bold: true; width: 110; height: 28; verticalAlignment: Text.AlignVCenter }
                    Text { text: " "; width: 170; height: 28 }
                    Text { text: " "; width: 110; height: 28 }
                }
            }
                }
            }
        }
    }

    Popup {
        id: livePlotPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.max(20, (radioRectangle.width - width) / 2)
        y: 64
        width: Math.min(radioRectangle.width - 40, 520)
        height: 430
        padding: 0

        function selectedFields() {
            var fields = [];
            if (plotOdomVx.checked) fields.push("odom_vx");
            if (plotOdomVy.checked) fields.push("odom_vy");
            if (plotOmegaZ.checked) fields.push("omega_z");
            if (plotAngleZ.checked) fields.push("angle_z");
            if (plotWheel0.checked) fields.push("wheel0");
            if (plotWheel1.checked) fields.push("wheel1");
            if (plotWheel2.checked) fields.push("wheel2");
            if (plotWheel3.checked) fields.push("wheel3");
            if (plotBattery.checked) fields.push("battery");
            if (plotCap.checked) fields.push("capacitance");
            return fields.join(",");
        }

        background: Rectangle {
            color: "#f6f6f6"
            border.color: "#9a9a9a"
            radius: 6
        }

        contentItem: Rectangle {
            color: "transparent"
            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: qsTr("Live Plot"); font.pixelSize: 22; font.bold: true; width: parent.width - 90 }
                    Button { text: qsTr("Close"); width: 80; onClicked: livePlotPopup.close() }
                }

                Grid {
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 8
                    width: parent.width

                    CheckBox { id: plotOdomVx; text: qsTr("   Vx(m/s)"); checked: true; width: 220 }
                    CheckBox { id: plotOdomVy; text: qsTr("Odom Vy(m/s)"); checked: true; width: 220 }
                    CheckBox { id: plotOmegaZ; text: qsTr("IMU Omega Z"); checked: false; width: 220 }
                    CheckBox { id: plotAngleZ; text: qsTr("IMU Angle Z"); checked: false; width: 220 }
                    CheckBox { id: plotWheel0; text: qsTr("Wheel 0"); checked: false; width: 220 }
                    CheckBox { id: plotWheel1; text: qsTr("Wheel 1"); checked: false; width: 220 }
                    CheckBox { id: plotWheel2; text: qsTr("Wheel 2"); checked: false; width: 220 }
                    CheckBox { id: plotWheel3; text: qsTr("Wheel 3"); checked: false; width: 220 }
                    CheckBox { id: plotBattery; text: qsTr("Battery(V)"); checked: false; width: 220 }
                    CheckBox { id: plotCap; text: qsTr("Capacitance(V)"); checked: false; width: 220 }
                }

                Row {
                    spacing: 10
                    Button {
                        text: qsTr("Start")
                        width: 110
                        onClicked: {
                            radioRectangle.cmdSender.startLivePlot(livePlotPopup.selectedFields());
                        }
                    }
                    Button {
                        text: qsTr("Stop")
                        width: 110
                        onClicked: {
                            radioRectangle.cmdSender.stopLivePlot();
                        }
                    }
                    Button {
                        text: qsTr("Clear")
                        width: 110
                        onClicked: {
                            radioRectangle.cmdSender.clearLivePlot();
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: trajectoryPopup
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.max(20, (radioRectangle.width - width) / 2)
        y: 24
        width: Math.min(radioRectangle.width - 40, 920)
        height: Math.min(radioRectangle.height - 70, 650)
        padding: 0

        property var historyItems: []
        property var historyNames: []
        property string statusTextValue: ""

        function shapeIndex(shape) {
            if (shape === "rectangle") return 1;
            if (shape === "circle") return 2;
            if (shape === "custom") return 3;
            return 0;
        }

        function refreshHistory() {
            var raw = radioRectangle.cmdSender.trajectoryHistoryJson();
            var items = [];
            try {
                items = JSON.parse(raw);
            } catch (e) {
                items = [];
            }
            trajectoryPopup.historyItems = items;
            var names = [];
            for (var i = 0; i < items.length; i++) {
                names.push(items[i].name);
            }
            trajectoryPopup.historyNames = names;
        }

        function parseCustomPoints() {
            var points = [];
            var rows = customPoints.text.split(/[;\n]+/);
            for (var i = 0; i < rows.length; i++) {
                var row = rows[i].trim();
                if (row.length === 0) continue;
                var parts = row.split(/[,\s]+/);
                if (parts.length < 2) continue;
                var x = Number(parts[0]);
                var y = Number(parts[1]);
                if (!isNaN(x) && !isNaN(y)) {
                    points.push({"x": x, "y": y});
                }
            }
            return points;
        }

        function buildSpec() {
            var shape = shapeBox.currentText;
            var spec = {
                "shape": shape,
                "length": lengthBox.value,
                "width": widthBox.value,
                "speed": speedBox.value,
                "repeat": repeatBox.value,
                "clockwise": clockwiseBox.checked,
                "closePath": closePathBox.checked
            };
            if (shape === "custom") {
                spec.points = parseCustomPoints();
            }
            return spec;
        }

        function applySpec(spec) {
            if (!spec) return;
            shapeBox.currentIndex = shapeIndex(spec.shape);
            lengthBox.value = Math.round(spec.length || 1000);
            widthBox.value = Math.round(spec.width || lengthBox.value);
            speedBox.value = Math.round(spec.speed || 500);
            repeatBox.value = Math.max(1, Math.round(spec.repeat || 1));
            clockwiseBox.checked = !!spec.clockwise;
            closePathBox.checked = !!spec.closePath;
            if (spec.points && spec.points.length > 0) {
                var rows = [];
                for (var i = 0; i < spec.points.length; i++) {
                    rows.push(Math.round(spec.points[i].x) + "," + Math.round(spec.points[i].y));
                }
                customPoints.text = rows.join(";");
            }
            previewCanvas.requestPaint();
        }

        function previewPoints() {
            var shape = shapeBox.currentText;
            var len = Math.max(1, lengthBox.value);
            var wid = Math.max(1, widthBox.value);
            if (shape === "custom") {
                var pts = parseCustomPoints();
                if (closePathBox.checked && pts.length > 1) {
                    pts.push({"x": pts[0].x, "y": pts[0].y});
                }
                return pts;
            }
            if (shape === "circle") {
                var radius = len / 2.0;
                var circle = [];
                for (var i = 0; i <= 48; i++) {
                    var a = 2.0 * Math.PI * i / 48.0;
                    circle.push({"x": radius + Math.cos(a) * radius, "y": radius + Math.sin(a) * radius});
                }
                return circle;
            }
            if (shape === "rectangle") {
                return [{"x":0,"y":0}, {"x":len,"y":0}, {"x":len,"y":wid}, {"x":0,"y":wid}, {"x":0,"y":0}];
            }
            return [{"x":0,"y":0}, {"x":len,"y":0}, {"x":len,"y":len}, {"x":0,"y":len}, {"x":0,"y":0}];
        }

        function runTrajectory() {
            var spec = buildSpec();
            if (spec.shape === "custom" && (!spec.points || spec.points.length < 2)) {
                trajectoryPopup.statusTextValue = "Custom needs at least 2 points";
                return;
            }
            if (rememberCheck.checked) {
                var saveName = historyName.text.trim();
                if (saveName.length === 0) {
                    saveName = spec.shape + "-" + Date.now();
                    historyName.text = saveName;
                }
                radioRectangle.cmdSender.saveTrajectoryHistory(saveName, JSON.stringify(spec));
                refreshHistory();
            }
            if (radioRectangle.cmdSender.startTrajectory(JSON.stringify(spec))) {
                if (!crazyStart.ifStarted) {
                    crazyStart.handleClickEvent();
                }
                trajectoryPopup.statusTextValue = "Running";
            } else {
                trajectoryPopup.statusTextValue = "Run failed";
            }
        }

        onOpened: {
            refreshHistory();
            previewCanvas.requestPaint();
        }

        background: Rectangle {
            color: "#f6f6f6"
            border.color: "#9a9a9a"
            radius: 6
        }

        contentItem: Rectangle {
            color: "transparent"

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: qsTr("Trajectory Test"); font.pixelSize: 22; font.bold: true; width: parent.width - 90 }
                    Button { text: qsTr("Close"); width: 80; onClicked: trajectoryPopup.close() }
                }

                Row {
                    spacing: 16
                    width: parent.width

                    Column {
                        width: 430
                        spacing: 8

                        Grid {
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 8
                            width: parent.width

                            ZText { text: qsTr("Shape") }
                            ComboBox {
                                id: shapeBox
                                width: 230
                                model: ["square", "rectangle", "circle", "custom"]
                                onCurrentIndexChanged: previewCanvas.requestPaint()
                            }

                            ZText { text: qsTr("Length/Diameter (mm)") }
                            SpinBox { id: lengthBox; editable: true; from: 1; to: 20000; value: 1000; width: 230; stepSize: 50; onValueModified: previewCanvas.requestPaint() }

                            ZText { text: qsTr("Width (mm)") }
                            SpinBox { id: widthBox; editable: true; from: 1; to: 20000; value: 1000; width: 230; stepSize: 50; onValueModified: previewCanvas.requestPaint() }

                            ZText { text: qsTr("Speed (mm/s)") }
                            SpinBox { id: speedBox; editable: true; from: 1; to: 8000; value: 500; width: 230; stepSize: 50 }

                            ZText { text: qsTr("Repeat") }
                            SpinBox { id: repeatBox; editable: true; from: 1; to: 100; value: 1; width: 230 }

                            CheckBox { id: clockwiseBox; text: qsTr("clockwise"); checked: false; width: 190; onCheckedChanged: previewCanvas.requestPaint() }
                            CheckBox { id: closePathBox; text: qsTr("close custom"); checked: true; width: 230; onCheckedChanged: previewCanvas.requestPaint() }
                        }

                        ZText { text: qsTr("Custom points: x,y; x,y; ...") }
                        TextArea {
                            id: customPoints
                            width: parent.width
                            height: 88
                            text: "0,0;1000,0;1000,1000;0,1000"
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            onTextChanged: previewCanvas.requestPaint()
                        }

                        Row {
                            spacing: 8
                            ComboBox {
                                id: historyBox
                                width: 190
                                model: trajectoryPopup.historyNames
                            }
                            Button {
                                text: qsTr("Load")
                                width: 70
                                enabled: historyBox.currentIndex >= 0 && trajectoryPopup.historyItems.length > 0
                                onClicked: {
                                    var item = trajectoryPopup.historyItems[historyBox.currentIndex];
                                    if (item) {
                                        historyName.text = item.name;
                                        trajectoryPopup.applySpec(item.spec);
                                    }
                                }
                            }
                            CheckBox { id: rememberCheck; text: qsTr("save"); checked: false; width: 70 }
                            TextField { id: historyName; width: 80; placeholderText: qsTr("name") }
                        }
                    }

                    Canvas {
                        id: previewCanvas
                        width: Math.max(260, parent.width - 446)
                        height: 360
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = "#ffffff";
                            ctx.fillRect(0, 0, width, height);
                            ctx.strokeStyle = "#c8c8c8";
                            ctx.lineWidth = 1;
                            ctx.strokeRect(0.5, 0.5, width - 1, height - 1);

                            var pts = trajectoryPopup.previewPoints();
                            if (!pts || pts.length < 2) {
                                return;
                            }
                            var minX = pts[0].x, maxX = pts[0].x, minY = pts[0].y, maxY = pts[0].y;
                            for (var i = 1; i < pts.length; i++) {
                                minX = Math.min(minX, pts[i].x);
                                maxX = Math.max(maxX, pts[i].x);
                                minY = Math.min(minY, pts[i].y);
                                maxY = Math.max(maxY, pts[i].y);
                            }
                            var pad = 24;
                            var spanX = Math.max(1, maxX - minX);
                            var spanY = Math.max(1, maxY - minY);
                            var scale = Math.min((width - pad * 2) / spanX, (height - pad * 2) / spanY);

                            function sx(x) { return pad + (x - minX) * scale; }
                            function sy(y) { return height - pad - (y - minY) * scale; }

                            ctx.strokeStyle = "#1976d2";
                            ctx.lineWidth = 3;
                            ctx.beginPath();
                            ctx.moveTo(sx(pts[0].x), sy(pts[0].y));
                            for (var j = 1; j < pts.length; j++) {
                                ctx.lineTo(sx(pts[j].x), sy(pts[j].y));
                            }
                            ctx.stroke();

                            ctx.fillStyle = "#2e7d32";
                            ctx.beginPath();
                            ctx.arc(sx(pts[0].x), sy(pts[0].y), 5, 0, 2 * Math.PI);
                            ctx.fill();
                            ctx.fillStyle = "#c62828";
                            ctx.beginPath();
                            ctx.arc(sx(pts[pts.length - 1].x), sy(pts[pts.length - 1].y), 5, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }
                }

                Row {
                    spacing: 10
                    Button { text: qsTr("Run"); width: 120; onClicked: trajectoryPopup.runTrajectory() }
                    Button {
                        text: qsTr("Stop")
                        width: 120
                        onClicked: {
                            radioRectangle.cmdSender.stopTrajectory();
                            trajectoryPopup.statusTextValue = "Stopped";
                        }
                    }
                    Text { text: trajectoryPopup.statusTextValue; font.pixelSize: 16; verticalAlignment: Text.AlignVCenter; height: 36 }
                }
            }
        }
    }

    Button{
        id:crazyStart;
        text:qsTr("Start") ;
        width:180 ;
        property bool ifStarted:false;
        anchors.right:parent.right;
        anchors.rightMargin: 20;
        anchors.top:groupBox2.bottom;
        anchors.topMargin: 10;
        // enabled : crazyConnect.ifConnected;//如果连接成功按钮才有效
        onClicked:{
            handleClickEvent();
        }
        function handleClickEvent(){
            if(ifStarted){//若开始，定时器关闭
                infoViewer.plotStop();
                timer.stop();
            }else{//若未开始，定时器打开
                infoViewer.plotStart();
                timer.start();
            }
            ifStarted = !ifStarted;
            text = (ifStarted ? qsTr("Stop") : qsTr("Start")) ;
        }
    }

    Image {
        id: colorImage
        z: 1000
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 12
        width: 220
        height: 220
        fillMode: Image.PreserveAspectFit
        source: Qt.resolvedUrl("color.jpg")
        cache: true
        visible: true
    }

    Rectangle {
        id: onlineCountBadge
        z: 999
        anchors.left: parent.left
        anchors.bottom: colorImage.top
        anchors.bottomMargin: 8
        anchors.leftMargin: 12
        radius: 8
        color: "#333333"  
        opacity: 0.85

        // padding
        width: Math.max(lineCounts.implicitWidth, lineAvgDelay.implicitWidth, lineHighDelay.implicitWidth) + 18
        height: badgeCol.implicitHeight + 12

        Column {
            id: badgeCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: lineCounts
                color: "white"
                font.family: "SimHei"
                font.pixelSize: 20
                font.bold: true
                text: "蓝车: " + (cmdSender ? cmdSender.onlineBlueCount : 0) + "   黄车: " + (cmdSender ? cmdSender.onlineYellowCount : 0)
            }

            Text {
                id: lineAvgDelay
                color: "white"
                font.family: "SimHei"
                font.pixelSize: 16
                font.bold: true
                text: "平均延迟: " + (cmdSender ? cmdSender.avgDelayMs : 0) + "ms"
            }

            Text {
                id: lineHighDelay
                color: "white"
                font.family: "SimHei"
                font.pixelSize: 16
                font.bold: true
                text: "高延迟: " + (cmdSender ? cmdSender.highDelayRobot : "无")
            }
        }
    }

}
