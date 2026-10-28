#!/usr/bin/env python3
# Ouvre "virsh console cirros-test", se connecte avec l'utilisateur cirros et lance quelques
# commandes, en affichant tout en direct dans le terminal. Le mot de passe (variable CIRROS_PW)
# n'est jamais affiche : il est remplace par <MOT_DE_PASSE_MASQUE> s'il apparait a l'ecran.
import os, pty, sys, time, select
PW = os.environ["CIRROS_PW"]

def show(data):
    sys.stdout.write(data.replace(PW, "<MOT_DE_PASSE_MASQUE>").replace("\r", "")); sys.stdout.flush()

def lire(fd, attente, afficher=True):
    fin = time.time() + attente; buf = ""
    while time.time() < fin:
        r, _, _ = select.select([fd], [], [], 0.3)
        if r:
            try: data = os.read(fd, 4096).decode(errors="replace")
            except OSError: break
            if not data: break
            buf += data
            if afficher: show(data)
    return buf

pid, fd = pty.fork()
if pid == 0:
    os.execvp("virsh", ["virsh", "-c", "qemu:///system", "console", "cirros-test", "--force"])
out = lire(fd, 2)
# Si une session est restee ouverte sur la console, on la ferme d'abord (sans l'afficher)
os.write(fd, b"\r"); out = lire(fd, 3, afficher=False)
if "login:" not in out:
    os.write(fd, b"exit\r"); lire(fd, 4, afficher=False)
os.write(fd, b"\r"); lire(fd, 3)
os.write(fd, b"cirros\r"); lire(fd, 3)
os.write(fd, PW.encode() + b"\r"); lire(fd, 5)
for cmd in ["grep PRETTY /etc/os-release", "ip -4 addr show eth0", "ip route", "ping -c 2 192.168.122.1", "ping -c 2 8.8.8.8"]:
    os.write(fd, cmd.encode() + b"\r"); lire(fd, 4)
os.write(fd, b"exit\r"); lire(fd, 2, afficher=False)
