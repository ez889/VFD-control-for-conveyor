PROGRAM PLC_PRG
var
    Motor1_FB: FB_Motor1_VFD;
    PostCam_FB: FB_PostCamera;

    Upstream_Ready_Line: BOOL;
    Line_Fault: BOOL;
end_var

Line_Fault:=
    Motor1_FB.fault_latch or
    PostCam_FB.fault_latch or
    (not Safety_OK);

Upstream_Ready_Line:=
    not Buffer_Full and
    (not Line_Fault);

Motor1_FB(
    start:= start,
    stop:= stop,
    reset_fault:= reset_fault,
    speed_set:= speed_set,
    PartInPosition:= PartInPosition,
    Upstream_Ready:= Upstream_Ready_Line,
    VFD_Ready:= VFD_Ready,
    VFD_Fault:= VFD_Fault,
    auto_hmi:= auto_hmi,
    Safety_OK:= Safety_OK
);

PostCam_FB(
    end1:= PartInPosition,
    end2:= End2,
    Buffer_Full:= Buffer_Full,
    Robot_Busy:= Robot_Busy,
    Robot_Done:= Robot_Done,
    Robot_Fault:= Robot_Fault,
    Safety_OK:= Safety_OK,
    reset_fault:= reset_fault
);
