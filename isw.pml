/* 1 enable access control, 0 disable */
#define AC 0
/* 1 enable the attacker, 0 disable */
#define ATTACKER 0
/* 1 check if the source of the message is the attacker, 0 disable*/
/*  SOURCE_CHECKER only has an impact if AC == 1 */
#define SOURCE_CHECKER 0
/* 1 forbids the buttons to be switched endlessly, 0 disable*/
/* Verification has been performed with this value at 0 */
#define NO_LOOP 0

#include "utility.pml"
#include "ltl.pml"

/* Custom types for handling names, could be replaced 
by a simple integer */
typedef name {
    byte ecu_name[2];
};

/* Custom types to send a message to predefined list
of two channels */
typedef mcast_group_of_2 {
    chan group[2];
};

/* Channels required for this modelisation */
chan buttons[2] = [0] of {pid, bool};

chan light_to_mainboard = [0] of {bool, bool, byte, name};
chan light_to_light_AC = [0] of {bool, name};

chan mainboard_to_auto_drive = [0] of { bool, name };
chan mainboard_to_light = [0] of {bool, name};
chan mainboard_to_light_AC = [0] of {bool, name};

/* Variables required for this modelisation */
bool auto_drive_status = 0;
bool light_status = 0;
bool mainboard_L_pressed = 0, mainboard_R_pressed = 0;
bool act_state = 0, mainboard_auto_drive_status = 0, mainboard_light_status = 0;
bool attack_succeed = 0;

name light_name; 
name mainboard_name; 
name auto_drive_name; 
name attacker_name;
name light_AC_name;


init
{
    light_name.ecu_name[0] = 'l';
    light_name.ecu_name[1] = 'i';

    mainboard_name.ecu_name[0] = 'e';
    mainboard_name.ecu_name[1] = 'l';

    auto_drive_name.ecu_name[0] = 'd';
    auto_drive_name.ecu_name[1] = 'r';

    attacker_name.ecu_name[0] = 'a';
    attacker_name.ecu_name[1] = 't';

    light_AC_name.ecu_name[0] = 'a';
    light_AC_name.ecu_name[1] = 'c';

    /* Starting all proctypes */
    atomic
    {
        run button()
        run button()
        #if AC == 1
        run light_AC()
        #endif
        #if NO_LOOP == 1
        run light_no_loop();
        #else
        run light_loop();
        #endif
        run mainboard();
        run auto_drive();
        #if ATTACKER == 1
        run attacker();
        #endif
    }
}

/* A simple button proctype, pressed is either 0 or 1 
the button endlessly sends its value so the light */
proctype button()
{
    bool pressed = 1;
    do
    ::  pressed = !pressed -> buttons[(_pid % 2)]!(_pid % 2),pressed;
    od
}

/* Cybersecurity monitor, enforces : */
/* Auto drive ON -> Light_ON -> Light OFF -> Auto drive OFF*/
proctype light_AC()
{
    bool command = 0;
    name sender;
    bool same = 0;

/* Our monitor accepts messages from the mainboard
   indicating that the auto drive is enabled
   We also wait for messages of the light to not
   block the proctype */
drive_on:
    do
    ::  mainboard_to_light_AC?command, sender ->
        if
        ::  command == 1 -> goto light_on;
        ::  else -> light_to_light_AC!0, light_AC_name -> goto drive_on;
        fi
    ::  light_to_light_AC?command, sender ->
        light_to_light_AC!0, light_AC_name;
    od
light_on:
    light_to_light_AC?command, sender ->
    same_name(sender, attacker_name, same);
    /* If we don't check the source of the command, than wether it is the attacker or not, command is executed */
    /* If SOURCE_CHECKER == 1 then the command is ONLY executed when it does not come from the attacker */
    if
    :: (command == 1 && same == 0) -> light_to_light_AC!command, light_AC_name -> goto light_off;
    #if SOURCE_CHECKER == 0
    :: (command == 1 && same == 1) -> attack_succeed = 1 -> light_to_light_AC!command, light_AC_name -> goto light_off;
    #endif
    :: else -> light_to_light_AC!0, light_AC_name -> goto light_on;
    fi
light_off:
    light_to_light_AC?command, sender ->
    if
    :: command == 0 -> light_to_light_AC!command, light_AC_name ->
        mainboard_to_light_AC!command, light_AC_name; goto drive_off;
    :: else -> light_to_light_AC!1, light_AC_name -> goto light_off;
    fi
drive_off:
    do
    ::  mainboard_to_light_AC?command, sender ->
        if
        ::  command == 0 -> goto drive_on;
        ::  else -> light_to_light_AC!0, light_AC_name -> goto drive_off;
        fi
    ::  light_to_light_AC?command, sender ->
        light_to_light_AC!0, light_AC_name;
    od
}

/* Basically the same implementation as the main one (down below)
   But with restrictive conditions two receive input from buttons 
   to avoid endlessly pressing and releasing a button without purpose 
   However, it blocks deactivation (both buttons will be 0 at the same time (except at start))
   Verifications have been made with the main implementation (NO_LOOP = 0) 
   
   This proctype must be considered as a work in progress
   */
proctype light_no_loop()
{
    bool light_L_pressed = 0, light_R_pressed = 0;
    bool light_L_pressed_old = 0, light_R_pressed_old = 0;
    bool light = 0
    name sender;
    light_status = 0;
    bool same = 0


start:
    do
    ::  (light_L_pressed_old == 0 || (light_L_pressed_old == 1 && light_R_pressed_old == 1)) -> buttons[0]?0,light_L_pressed -> goto forward_left;
    ::  (light_R_pressed_old == 0 || (light_L_pressed_old == 1 && light_R_pressed_old == 1)) -> buttons[1]?1,light_R_pressed -> goto forward_right;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od

forward_left:
    do
    ::  light_to_mainboard!0,light_L_pressed, 
        (light_L_pressed != light_L_pressed_old -> 1 : 0), light_name 
            -> light_L_pressed_old = light_L_pressed -> goto start;
    ::  (light_R_pressed_old == 0 || (light_L_pressed_old == 1 && light_R_pressed_old == 1)) -> buttons[1]?1,light_R_pressed -> goto forward_both;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od

forward_right:
    do
    ::  (light_L_pressed_old == 0 || (light_L_pressed_old == 1 && light_R_pressed_old == 1)) -> buttons[0]?0,light_L_pressed -> goto forward_both;
    ::  light_to_mainboard!1,light_R_pressed, 
        (light_R_pressed != light_R_pressed_old -> 1 : 0), light_name 
            -> light_R_pressed_old = light_R_pressed -> goto start;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od
    
forward_both:
    do
    ::  light_to_mainboard!0,light_L_pressed, 
        (light_L_pressed != light_L_pressed_old -> 1 : 0), light_name 
            -> light_L_pressed_old = light_L_pressed -> goto forward_right;
    ::  light_to_mainboard!1,light_R_pressed, 
        (light_R_pressed != light_R_pressed_old -> 1 : 0), light_name 
            -> light_R_pressed_old = light_R_pressed -> goto forward_left;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od
}

/* Main implementation for the light ECU */
proctype light_loop()
{
    bool light_L_pressed = 0, light_R_pressed = 0;
    bool light_L_pressed_old = 0, light_R_pressed_old = 0;
    bool light = 0;
    name sender;
    light_status = 0;
    bool same = 0

/* Start state, we wait an input from a button 
    If a message from the mainboard (note this can also be the attacker) is received
    The light is switched ON (the monitor is synchronised if AC == 1)*/
start:
    do
    ::  buttons[0]?0,light_L_pressed -> goto forward_left;
    ::  buttons[1]?1,light_R_pressed -> goto forward_right;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od

/* A message from the left button has been received 
   and must be forwarded to the mainboard 
   If it is a success, back to start state
   The light can still receive messages from the riht button
   or the mainboard (same as start state) */
forward_left:
    do
    ::  light_to_mainboard!0,light_L_pressed, 
        (light_L_pressed != light_L_pressed_old -> 1 : 0), light_name 
            -> light_L_pressed_old = light_L_pressed -> goto start;
    ::  buttons[1]?1,light_R_pressed -> goto forward_both;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od

/* A message from the right button has been received 
   and must be forwarded to the mainboard 
   If it is a success, back to start state
   The light ECU can still receive messages from the left button
   or the mainboard (same as start state) */
forward_right:
    do
    ::  buttons[0]?0,light_L_pressed -> goto forward_both;
    ::  light_to_mainboard!1,light_R_pressed, 
        (light_R_pressed != light_R_pressed_old -> 1 : 0), light_name 
            -> light_R_pressed_old = light_R_pressed -> goto start;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od

/* Messages from both right and left buttons have been received 
   and must be forwarded to the mainboard 
   One of those is forwarded and back to 
   forward_right if left was forwarded
   forward_left if right was forwarded
   The light ECU can still receive messages from the left button
   or the mainboard (same as start state) */
forward_both:
    do
    ::  light_to_mainboard!0,light_L_pressed, 
        (light_L_pressed != light_L_pressed_old -> 1 : 0), light_name 
            -> light_L_pressed_old = light_L_pressed -> goto forward_right;
    ::  light_to_mainboard!1,light_R_pressed, 
        (light_R_pressed != light_R_pressed_old -> 1 : 0), light_name 
            -> light_R_pressed_old = light_R_pressed -> goto forward_left;
    #if AC == 1
    ::  mainboard_to_light?light, sender -> AC_check(light, sender);
    #else
    ::  mainboard_to_light?light_status, sender; same_name(sender, attacker_name, same);
        if
        ::  same == 1 -> attack_succeed = 1;
        ::  same == 0 -> attack_succeed = 0;
        fi
    #endif
    od
}

/* Our mainboard, handling the communication logic
   between our light and the automatic driving ECU */
proctype mainboard()
{
    name sender;
    #if AC == 1
    mcast_group_of_2 AC_light_group;
    AC_light_group.group[0] = mainboard_to_auto_drive;
    AC_light_group.group[1] = mainboard_to_light_AC;
    #endif
again:
    /* We wait for every input of the light ECU */
    do
    ::  light_to_mainboard?0,mainboard_L_pressed, 1, sender -> break;
    ::  light_to_mainboard?1,mainboard_R_pressed, 1, sender -> break;
    ::  light_to_mainboard?0,mainboard_L_pressed, 0, sender;
    ::  light_to_mainboard?1,mainboard_R_pressed, 0, sender;
    od
    if
    /* If all the conditions are met the mainboard enables the automatic driving feature 
       If AC == 1 the monitor is synchronized, then the light is turned ON */
    ::  mainboard_L_pressed && mainboard_R_pressed && !mainboard_auto_drive_status &&  !mainboard_light_status && !act_state->
        #if AC == 1
        send_to(AC_light_group, 1, mainboard_name) -> mainboard_auto_drive_status = 1; 
        #else
        mainboard_to_auto_drive!1, mainboard_name -> mainboard_auto_drive_status = 1;
        #endif
        mainboard_to_light!1, mainboard_name -> mainboard_light_status = 1;

    /* If all the conditions are met the mainboard switches the light OFF 
       If AC == 1 the monitor is synchronized, then the automatic driving feature is disabled */
    ::  mainboard_L_pressed && mainboard_R_pressed &&  mainboard_auto_drive_status && mainboard_light_status && act_state -> 
        mainboard_to_light!0, mainboard_name -> mainboard_light_status = 0; 
        #if AC == 1
        mainboard_to_light_AC?0, light_AC_name;
        send_to(AC_light_group, 0, mainboard_name) -> mainboard_auto_drive_status = 0;
        #else
        mainboard_to_auto_drive!0, mainboard_name -> mainboard_auto_drive_status = 0;
        #endif

    /* If both buttons are released and everything is ON/enabled, act_state is switched to 1
       This is to know if next action is switching ON or OFF */
    :: !mainboard_L_pressed && !mainboard_R_pressed && mainboard_auto_drive_status && mainboard_light_status && !act_state -> 
        act_state = 1;

    /* If both buttons are released and everything is OFF/disabled, act_state is switched to 1
       This is to know if next action is switching ON or OFF */
    :: !mainboard_L_pressed && !mainboard_R_pressed && !mainboard_auto_drive_status && !mainboard_light_status && act_state -> 
        act_state = 0;
    
    /* If nothing work, we wait for another input*/
    ::  else -> skip;
    fi
    goto again;
}

/* Our (out-of-scope) automatic driving ECU */
proctype auto_drive()
{
    do
    :: mainboard_to_auto_drive?auto_drive_status, mainboard_name;
    od
}

/* Our attacker which endlessly tries to switch ON the light*/
proctype attacker()
{
    do
    :: mainboard_to_light!1, attacker_name;
    od
}
