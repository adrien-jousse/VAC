/* Prettier printing of a name (for debugging purposes) */
inline print_name(ecu)
{
    int i;
    for (i in ecu.ecu_name)
    {
        printf("%c", ecu.ecu_name[i]);
    }
    printf("/n");
}

/* Send a command from a sender to channels in mcast.group */
inline send_to(mcast, command, sender)
{
    int i;
    atomic {
        for (i in mcast.group)
        {
                mcast.group[i]!command, sender;
        }
    }
}

/*  */
inline AC_check(light, sender)
{
    light_to_light_AC!light, sender;
    light_to_light_AC?light_status, sender;
}

/* Compares two arrays used as names, should be replaced by simpler integer ... */
inline same_name(name1, name2, res)
{
    if 
    :: name1.ecu_name[0] == name2.ecu_name[0] && name1.ecu_name[1] == name2.ecu_name[1] -> res = 1;
    :: else -> res = 0;
    fi
}