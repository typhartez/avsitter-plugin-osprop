/*
 * [AV]object - Used in props for attaching, derezzing, etc.
 * (OpenSim version)
 * (OpenSim version which keeps rotation on attached props)
 * Fix by Typhaine Artez (check typhfix in the code)
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright © the AVsitter Contributors (http://avsitter.github.io)
 * AVsitter™ is a trademark. For trademark use policy see:
 * https://avsitter.github.io/TRADEMARK.mediawiki
 *
 * Please consider supporting continued development of AVsitter and
 * receive automatic updates and other benefits! All details and user
 * instructions can be found at http://avsitter.github.io
 */

string version = "2.020";
integer comm_channel;
integer local_attach_channel = -2907539;
integer listen_handle;
integer prop_type;
integer prop_id;
integer prop_point;
integer experience_denied_reason;
key originalowner;
key parentkey;
key give_prop_warning_request;
vector prop_rotation;   // typhfix: added to store rotation

unsit_all()
{
    integer i = llGetNumberOfPrims();
    while (llGetAgentSize(llGetLinkKey(i)) != ZERO_VECTOR)
    {
        llUnSit(llGetLinkKey(i));
        i--;
    }
}

integer verbose = 5;

Out(integer level, string out)
{
    if (verbose >= level)
    {
        llOwnerSay(llGetScriptName() + "[" + version + "] " + out);
    }
}

default
{
    on_rez(integer start)
    {
        if (start)
        {
            state prop;
        }
    }
}

state prop
{
    state_entry()
    {
        if (llGetLinkNumber() < 2)
        {
            if (llGetStartParameter() <= -10000000)
            {
                string start_param = (string)llGetStartParameter();
                prop_type = (integer)llGetSubString(start_param, -1, -1);
                prop_point = (integer)llGetSubString(start_param, -3, -2);
                prop_id = (integer)llGetSubString(start_param, -5, -4);
                comm_channel = (integer)llGetSubString(start_param, 0, -6);
                listen_handle = llListen(comm_channel, "", "", "");
                llSay(comm_channel, "REZ|" + (string)prop_id);
            }
            else
            {
            }
        }
        if (prop_type != 2 && prop_type != 1)
        {
            if (llGetInventoryType("[AV]sitA") == INVENTORY_NONE)
            {
                llSetClickAction(CLICK_ACTION_NONE);
            }
        }
        else
        {
            llSetClickAction(CLICK_ACTION_TOUCH);
        }
    }

    attach(key id)
    {
        if (comm_channel)
        {
            if (llGetAttached())
            {
                llListen(local_attach_channel, "", "", "");
                llSay(comm_channel, "ATTACHED|" + (string)prop_id);
                llSay(local_attach_channel, "LOCAT|" + (string)llGetAttached());
                if (experience_denied_reason == 17)
                {
                    if (llGetOwner() == originalowner)
                    {
                        list details;
                        if (llList2String(details, 3) == "17")
                        {
                            llSay(comm_channel, "NAG|" + llList2String(details, 0));
                        }
                    }
                }
            }
            else
            {
                llSay(comm_channel, "DETACHED|" + (string)prop_id);
            }
        }
    }

    touch_start(integer touched)
    {
        if ((!llGetAttached()) && (prop_type == 2 || prop_type == 1))
        {
            llRequestPermissions(llDetectedKey(0), PERMISSION_ATTACH);
        }
    }

    run_time_permissions(integer permissions)
    {
        if (permissions & PERMISSION_ATTACH)
        {
            if (llGetAttached())
            {
                llDetachFromAvatar();
            }
            else
            {
                llAttachToAvatarTemp(prop_point);
                // typhfix: apply stored rotation
                if (ZERO_VECTOR != prop_rotation) {
                    llSetLocalRot(llEuler2Rot(prop_rotation * DEG_TO_RAD));
                }
            }
        }
        else
        {
            llSay(comm_channel, "DEREZ|" + (string)prop_id);
            llDie();
        }
    }

    on_rez(integer start)
    {
        if (!llGetAttached())
        {
            state restart_prop;
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        list data = llParseString2List(message, ["|"], []);
        string command = llList2String(data, 0);
        if (llList2String(data, 0) == "LOCAT" && llGetOwnerKey(id) == llGetOwner() && llList2String(data, 1) == (string)llGetAttached())
        {
            llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
        }
        else if (command == "ATTACHTO" && prop_type == 1 && (key)llList2String(data, 2) == llGetKey())
        {
            if (llGetAgentSize((key)llList2String(data, 1)) == ZERO_VECTOR)
            {
                llSay(comm_channel, "DEREZ|" + (string)prop_id);
                // typhfix: prevent an error on OpenSim 0.8.2 console
                llSleep(0.5);
                llDie();
            }
            else
            {
                // typhfix: store rotation from the message
                prop_rotation = (vector)llList2String(data, 3);
                llRequestPermissions(llList2Key(data, 1), PERMISSION_ATTACH);
            }
        }
        else if (llGetSubString(command, 0, 3) == "REM_")
        {
            integer remove;
            if (command == "REM_ALL")
            {
                remove = TRUE;
            }
            else if (command == "REM_INDEX" || (command == "REM_WORLD" && !llGetAttached()))
            {
                if (~llListFindList(data, [(string)prop_id]))
                {
                    remove = TRUE;
                }
            }
            else if (llGetAttached() && command == "REM_WORN" && (key)llList2String(data, 1) == llGetOwner())
            {
                remove = TRUE;
            }
            if (remove)
            {
                if (llGetAttached())
                {
                    llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
                }
                else
                {
                    if (llGetAgentSize(llGetLinkKey(llGetNumberOfPrims())) != ZERO_VECTOR)
                    {
                        unsit_all();
                        llSleep(1);
                    }
                    llSay(comm_channel, "DEREZ|" + (string)prop_id);
                    // typhfix: prevent an error on OpenSim 0.8.2 console
                    llSleep(0.5);
                    llDie();
                }
            }
        }
        else if (message == "PROPSEARCH" && !llGetAttached())
        {
            llSay(comm_channel, "SAVEPROP|" + (string)prop_id);
        }
    }
}

state restart_prop
{
    state_entry()
    {
        state prop;
    }
}
