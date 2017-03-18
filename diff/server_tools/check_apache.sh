#!/bin/bash
if [ "pgrep -f apache" = "" ]; then
    /etc/init.d/apache2 restart
fi
                                       