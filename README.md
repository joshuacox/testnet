# testnet
Network Test

This was a simple shell script to detect if networking failed on an OPNsense router using modest hardware that tended to end up in some sort of failed state.  

In which case reboot.

Ugly I know. But it just keeps evolving.  I am certain that one day this will evolve into skynet and decide to extinguish humanity, but for now it reboots my router when it no longer makes the networky.

## install

1. `make install`
1. copy example.testnet to ~/.testnet
1. edit it
1. replace example.com with your domain or a known one that pings
1. replace the 10.x.x.x addresses with your own.
1. Pay special attention to the `this_class_c` variable and make that a class c network that is close to your network.
