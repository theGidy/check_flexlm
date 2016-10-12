# check_flexlm

# Fork description
It's a fork from https://exchange.nagios.org/directory/Plugins/License-Management/check_flexlm/details 

# Changelog
## v1.0.1
  - add performance data to the output
  - change lmstat paramter from -A to -a

# Original readme

Checks Macrovision FLEXlm license servers. (Requires the lmutil utility for your OS running Nagios - see www.macrovision.com to obtain this).
Yeah, I know the standard Nagios plugins package contains a check_flexlm plugin. But it has not been updated in quite a while, didn't work properly for me, and most of its functionality seems concerned with license server triads. That's great if you actually use triads, but I've been working with various FLEXlm-licensed software packages for over 10 years and have never seen anyone use a triad. There are usually so many other points of failure to worry about, it's just not that critical considering the additional management complexity.

If you use triads, my script may not even work for you.

If you don't use a triad, however, this script probably gives you more and better information than the standard check_flexlm plugin.

It will output an OK state if the license server process is running and all licensed modules are available for checkout.

It will output a CRITICAL state if the server is down or unreachable.

It will output a WARNING state if any of the modules on your license server are maxxed out. (for example, you have 3 licenses of module foo, and all 3 are currently in use.)

The idea or intent behind this WARNING behavior is that it could be useful if you want to know how often you are running close to the limit of a particular software feature. This may help you decide whether you should consider purchasing more seats. 
