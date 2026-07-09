#!/usr/bin/env python3
import libvirt
import sys

CONN = "qemu:///system"
DOM=sys.argv[1]
print(DOM)
def getIP():
    conn = libvirt.open(CONN)
    domain = conn.lookupByName(DOM)
    if domain:
        try:
            dom_ifaces = domain.interfaceAddresses(libvirt.VIR_DOMAIN_INTERFACE_ADDRESSES_SRC_AGENT)
            if dom_ifaces != None:
                for iface in dom_ifaces:
                    if iface == 'lo':
                        continue
                    for addr in dom_ifaces[iface]['addrs']:
                        if addr['type'] == 0:
                            print( addr['addr'])
                            #sys.exit(0)
        
        except (TypeError,libvirt.libvirtError):
            #print("Error")
            pass

    else:
        print("Domain not found")
      
if __name__ == '__main__':
    getIP()
