var_input
    start: BOOL;
    stop: BOOL;
    reset_fault: BOOL;          //button from hmi
    speed_set: INT;
    PartInPosition: BOOL;
    Upstream_Ready: BOOL;       //previous part is ready for next step
    
    VFD_Ready: BOOL;
    VFD_Fault: BOOL;
    auto_hmi: BOOL;             //auto regime for hmi
    Safety_OK: BOOL;            //lanac za bezbednost
end_var

var_output
    auto_active: BOOL;              //lamp
    manual_active: BOOL;            //lamp
    fault: BOOL;                    //lamp
    jam: BOOL;                      //lamp
    safety_chain_open: BOOL;        //lamp
    
    VFD_start: BOOL;                //command for VFD
    fault_latch: BOOL;
    VFD_FaultReset: BOOL;           //command for reset VFD
    Motor1_ReadyForNext: BOOL;
end_var


var
    Tx: ARRAY[0..1] OF WORD;        //CONTROL WORD AND SPEED
    Rx: ARRAY[0..1] OF WORD;        //RECEIVE WORD AND ACTUAL SPEED

    logika: INT:=0;                 //step of algorithm
    Running: BOOL;
    jam_fault: BOOL;
    timer1: TON;
    SpeedCmd: INT;
    init_done: BOOL:= FALSE;
end_var

    if not init_done then
        logika:= 0;
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= 16#0000;
        Tx[1]:= 16#0000;
        fault_latch:= FALSE;
        jam_fault:= FALSE;
        jam:= FALSE;

        init_done:= TRUE;
    end_if

    auto_active:= auto_hmi;
    manual_active:= not auto_hmi;
    safety_chain_open:= not Safety_OK;


//lamp of fault:
fault:= fault_latch or jam_fault or VFD_Fault or not Safety_OK

//reset from button of hmi:
VFD_FaultReset:= reset_fault;

//main algorithm with steps:
case logika of
    0:  
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= Tx[0] and not 16#0001;

        //global reset of faults
        if reset_fault and Safety_OK and (not VFD_Fault) then
            jam:= FALSE;
            jam_fault:= FALSE;
            fault_latch:= FALSE;
        end_if

        if start
            and Safety_OK
            and VFD_Ready
            and not VFD_Fault
            and not fault_latch
            and not jam_fault then
                logika:= 10;
        end_if

    10:
        if stop then
            logika:=0;
        elsif auto_hmi then         //regime on hmi= auto
            if start
                and Upstream_Ready
                and Safety_OK
                and VFD_Ready
                and not fault_latch
            then
                VFD_start:= TRUE;
                Running:= TRUE;
                Tx[0]:= Tx[0] or 16#0001    //RUN=1
                logika:= 20;
            end_if
        else
            if start            //regime on hmi= manual
                and Safety_OK
                and VFD_Ready
                and not fault_latch then
                    VFD_start:= TRUE;
                    Running:= TRUE;
                    Tx[0]:= Tx[0] or 16#0001;
                    logika:= 20;
            end_if
        end_if

      20:
          //speed calculation:
          if auto_hmi then
                if speed_set<50 then        //auto
                SpeedCmd:= 50;
              else
                  SpeedCmd:= speed_set;
              end_if
          else
              SpeedCmd:= speed_set        //manual
          end_if

          if SpeedCmd<0 then
              SpeedCmd:=0;
          elsif   SpeedCmd>100 then
              SpeedCmd:=100;
          end_if
          Tx[1]:= INT_TO_WORD(SpeedCmd);

    timer1(IN:=Running and not PartInPosition, PT:=T#15s);

    if timer1.Q and (not PartInPosition) then
        jam:= TRUE;
        jam_fault:= TRUE;
        fault_latch:= TRUE;
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= Tx[0] and not 16#0001       //run= 0
        logika:= 30;
    end_if

if auto_hmi and PartInPosition then
    Running:= FALSE;
    VFD_start:= FALSE;
    Tx[0]:= Tx[0] and not 16#0001;
    logika:= 0;
end_if

if stop then
    Running:= FALSE;
    VFD_start:= FALSE;
    Tx[0]:= Tx[0] and not 16#0001;
    logika:= 0;
end_if

    30:                       //jam error, push the reset
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= Tx[0] and not 16#0001;

        if reset_fault
            and Safety_OK
            and (not VFD_Fault) then
                jam:= FALSE;
                jam_fault:= FALSE;
                fault_latch:= FALSE;
                logika:= 0;
        end_if

    40:                      //VFD/safety error, push the reset
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= Tx[0] and not 16#0001      //run=0

        if reset_fault
            and Safety_OK
            and (not VFD_Fault) then
                fault_latch:= FALSE;
                logika:= 0;
        end_if
end_case

//global reaction for safety and VFD_Fault:
    if (not Safety_OK) or VFD_Fault then
        Running:= FALSE;
        VFD_start:= FALSE;
        Tx[0]:= Tx[0] and not 16#0001       //run=0
        fault_latch:= TRUE;
        logika:= 40;
    end_if

   Motor1_ReadyForNext:= FALSE;

    IF logika=0
        AND NOT fault_latch
        AND Safety_OK
        AND NOT VFD_Fault then
        Motor1_ReadyForNext:= TRUE;
    END_IF
