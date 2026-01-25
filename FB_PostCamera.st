FUNCTION_BLOCK FB_PostCamera
var_input
    end1: BOOL;   // part at camera position
    end2: BOOL;   // part at end of motor2
    Buffer_Full: BOOL;

    Robot_Busy: BOOL;
    Robot_Done: BOOL;
    Robot_Fault: BOOL;

    Safety_OK: BOOL;
    reset_fault: BOOL;
end_var

var_output
    motor2: BOOL;
    robot: BOOL;

    jam_motor2 : BOOL;
    fault_latch: BOOL;
end_var

var
    state: INT:= 0;
    t_motor2: TON;
    init_done: BOOL:= FALSE;
end_var

if not init_done then
    state:= 0;
    motor2:= FALSE;
    robot:= FALSE;
    jam_motor2:= FALSE;
    fault_latch:= FALSE;
    init_done:= TRUE;
end_if

case state of

0:
    motor2:= FALSE;
    robot := FALSE;

    if end1 and Safety_OK and (not fault_latch) then
        state:= 10;
    end_if

10:                 //waiting for robot
    robot:= TRUE;

    if Robot_Busy then
        state:= 20;
    elsif Robot_Fault then
        fault_latch:= TRUE;
        state:= 40;
    end_if

20:                 //working
    robot:= TRUE;

    if Robot_Done then
        robot:= FALSE;
        state:= 30;
    elsif Robot_Fault then
        fault_latch:= TRUE;
        state:= 40;
    end_if

30:                 //move motor2
    if not Buffer_Full then
        motor2:= TRUE;
    else
        motor2:= FALSE;
    end_if

    // jam detection
    t_motor2(IN:= motor2 and (not end2), PT:= T#10s);

    if t_motor2.Q then
        jam_motor2:= TRUE;
        fault_latch:= TRUE;
        motor2:= FALSE;
        state:= 40;
    end_if

    if end2 then
        motor2:= FALSE;
        state:= 0;
    end_if

40:                  //fault
    motor2:= FALSE;
    robot:= FALSE;

    if reset_fault AND Safety_OK then
        jam_motor2:= FALSE;
        fault_latch:= FALSE;
        state:= 0;
    end_if

end_case


if not Safety_OK then
    motor2:= FALSE;
    robot:= FALSE;
    fault_latch:= TRUE;
    state:= 40;
end_if

