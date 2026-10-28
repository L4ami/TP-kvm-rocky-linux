#!/usr/bin/env python3
# Se connecte a la console serie de la VM cirros-test (virsh console), ouvre une session
# avec l'utilisateur cirros et lance quelques commandes. Le mot de passe est lu dans
# la variable d'environnement CIRROS_PW (il n'est jamais affiche).
import os, pty, sys, time, select

def lire(fd, attente):
    fin = time.time() + attente; out = b""
    while time.time() < fin:
        r, _, _ = select.select([fd], [], [], 0.5)
        if r:
            try: data = os.read(fd, 4096)
            except OSError: break
            if not data: break
            out += data
    return out.decode(errors="replace")

pid, fd = pty.fork()
if pid == 0:
    os.execvp("virsh", ["virsh", "-c", "qemu:///system", "console", "cirros-test", "--force"])
sortie = lire(fd, 3)
os.write(fd, b"\r"); sortie += lire(fd, 5)
if "login:" in sortie:
    os.write(fd, b"cirros\r"); sortie += lire(fd, 5)
    os.write(fd, os.environ["CIRROS_PW"].encode() + b"\r"); sortie += lire(fd, 8)
for cmd in ["cat /etc/os-release | head -3", "uname -a", "ip -4 addr show eth0", "ip route", "ping -c 3 192.168.122.1", "ping -c 3 8.8.8.8", "exit"]:
    os.write(fd, cmd.encode() + b"\r"); sortie += lire(fd, 8)
os.write(fd, b"\x1d")   # Ctrl+] pour quitter virsh console
sortie += lire(fd, 2)
print(sortie.replace("\r", ""))
