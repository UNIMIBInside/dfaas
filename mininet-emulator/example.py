"""
This is an example of a simple 3-nodes DFaaS environment.
"""
from mininet.net import Containernet
from mininet.node import Controller
from mininet.cli import CLI
from mininet.link import TCLink
from mininet.log import info, setLogLevel

setLogLevel('info')

net = Containernet(controller=Controller)
net.addController('c0')

info('*** Adding container\n')
n1 = net.addDocker('n1', ip='10.0.0.1', dcmd='/sbin/init --log-level=err', dimage="platform:latest", runtime='sysbox-runc')
n2 = net.addDocker('n2', ip='10.0.0.2', dcmd='/sbin/init --log-level=err', dimage="platform:latest", runtime='sysbox-runc')
n3 = net.addDocker('n3', ip='10.0.0.3', dcmd='/sbin/init --log-level=err', dimage="platform:latest", runtime='sysbox-runc')

info('*** Setup network\n')
s1 = net.addSwitch('s1')
s2 = net.addSwitch('s2')
net.addLink(n1, s1)
net.addLink(s1, s2, cls=TCLink, delay='100ms', bw=1)
net.addLink(s2, n2)
net.addLink(s2, n3)

info('*** Starting network\n')
net.start()

CLI(net)

net.stop()