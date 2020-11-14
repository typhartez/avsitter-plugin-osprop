# Overview

(AVsitter2)[https://github.com/AVsitter/AVsitter] has been ported to OpenSim, but there are still issues. In particular the *prop* plugin does not keep rotation on rezzed objects that are aimed to be attached, as depicted in this (AVsitter issue)[https://github.com/AVsitter/AVsitter/issues/74]. AVsitter developers stated (in purpose) that's it's not related to AVsitter, but an OpenSim bug, and the issue has been (reported to OpenSim mantis)[http://opensimulator.org/mantis/view.php?id=8364]. Unfortunately, this bug is opened since 2018 and still in the *new* state.

**So how can users do?** Well, doing a fix on AVsitter to compensate OpenSim bug. That's what this project is about.

## For users

The plugin works exactly the same than the original one, just replace *[AV]object* with *[AV]osobject* inside props, and replace *[AV]prop* with *[AV]osprop* in the main sitting object. Just check that the rotation of the object is correctly set in the `PROP1` line.

## For interested developers

The workaround is pretty simple. As the rotation is stored in the *AVpos* notecard with the `PROP1` line, we can forward it to the rezzed object in the *[AV]prop* script:

```lsl
if (sitter_key != NULL_KEY && llList2String(data, 0) == "REZ" && llList2Integer(prop_types, prop_index) == 1)
{
    // typhfix: add rotation to the ATTACHTO command
    vector rot = llList2Vector(prop_rotations, prop_index);
    llSay(comm_channel, "ATTACHTO|" + (string)sitter_key + "|" + (string)id + "|" + (string)rot);
}
```

On the other side, in the *[AV]object* script, we keep storage for received rotation in the `ATTACHTO` command:
```lsl
vector prop_rotation;   // typhfix: added to store rotation
```

```lsl
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
```

And during permission handling, if the rotation was given, apply it:
```lsl
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
```
