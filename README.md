# testnet
Network Test

This was a simple shell script to detect if networking failed on an OPNsense router using modest hardware that tended to end up in some sort of failed state.  

In which case reboot.

Ugly I know. But it just keeps evolving.  I am certain that one day this will evolve into skynet and decide to extinguish humanity, but for now it reboots my router when it no longer makes the networky.

## install

`make install`

then copy example.testnet to ~/.testnet

and edit it, replace exaple.com with your domain or a known one that pings, and the 10 dot addresses with your own.  Pay special attention to the this_class_c and make that a class c network that is close to your network.
