#!/bin/bash
trap : TERM INT

# Apply cfconfig file if one was specified

if [ "$cfconfigfile" != "" ]
then
        if [ -r "$cfconfigfile" ]; then
                echo "Applying CFConfig file $cfconfigfile ..."
                box cfconfig import from=$cfconfigfile to=/opt/coldfusion11/cfusion toFormat=adobe@11
        else
                echo "$cfconfigfile does not exist or is not readable."
        fi
else
        echo "No cfconfigfile environment variable specified; continuing to server start ..."
fi

/opt/coldfusion11/cfusion/bin/cfstart.sh
/usr/bin/tail -f /opt/coldfusion11/cfusion/logs/coldfusion-out.log /opt/coldfusion11/cfusion/logs/coldfusion-error.log