/* If the light is ON, the auto drive must always be enabled */
ltl phi {always (light_status implies auto_drive_status)};

/* The attacker must never switch ON the light */
ltl psi {always(!attack_succeed)}

/* If both buttons are pressed (and we are not switching off the light), the light must be ON in the future */
ltl xi {always( ( mainboard_L_pressed && mainboard_R_pressed && !act_state ) implies eventually(light_status) )}

ltl all { (always(light_status implies auto_drive_status)) && 
          (always(!attack_succeed)) && 
          (always( ( mainboard_L_pressed && mainboard_R_pressed && !act_state ) implies eventually(light_status) )) }
