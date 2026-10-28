---
title: TP KVM - Rocky Linux 9.8
tags: virtualisation, kvm, libvirt, rocky-linux, rhel
---

> Dépôt GitHub : https://github.com/L4ami/TP-kvm-rocky-linux (les images s'afficheront une fois le dépôt publié).

# TP – Installer KVM pendant une nouvelle installation de Rocky Linux 9 (clone de RHEL)

> Semaine de cours « Virtualisation ».
> TP précédents : ESXi, puis OpenStack. Ce TP : **KVM**.
> Référence suivie : la documentation Red Hat *« Installing KVM with a new Red Hat Enterprise Linux installation »*.

---

## Sommaire

1. [But du TP en une phrase](#1-but-du-tp-en-une-phrase)
2. [La théorie avant de commencer](#2-la-théorie-avant-de-commencer)
3. [Le matériel et les logiciels utilisés](#3-le-matériel-et-les-logiciels-utilisés)
4. [Schéma de l'architecture](#4-schéma-de-larchitecture)
5. [Étape 0 – Vérifier l'état de Windows](#étape-0--vérifier-létat-de-windows)
6. [Étape 1 – Vérifier l'ISO de Rocky Linux](#étape-1--vérifier-liso-de-rocky-linux)
7. [Étape 2 – Écrire le fichier kickstart (installation automatique)](#étape-2--écrire-le-fichier-kickstart-installation-automatique)
8. [Étape 3 – Créer la VM dans VMware et lancer l'installation](#étape-3--créer-la-vm-dans-vmware-et-lancer-linstallation)
9. [Étape 4 – Se connecter en SSH et vérifier KVM](#étape-4--se-connecter-en-ssh-et-vérifier-kvm)
10. [Étape 5 – Créer une VM de test (CirrOS) dans KVM](#étape-5--créer-une-vm-de-test-cirros-dans-kvm)
11. [Problèmes rencontrés et solutions](#problèmes-rencontrés-et-solutions)
12. [Lien avec les TP ESXi et OpenStack](#lien-avec-les-tp-esxi-et-openstack)
13. [Arborescence du dépôt](#arborescence-du-dépôt)
14. [Glossaire](#glossaire)
15. [Fiche de révision pour l'oral](https://github.com/L4ami/TP-kvm-rocky-linux/blob/main/docs/fiche-questions-oral.md)

> 📸 **Captures d'écran** : toutes les captures sont de vraies captures de fenêtres Windows. Les captures 07 et 08 montrent la fenêtre VMware Workstation. Les autres montrent une fenêtre PowerShell où la commande a été lancée (et, à partir de la 09, connectée en SSH à `kvm-rocky`). Les scripts qui ouvrent la fenêtre, lancent la commande puis la capturent sont dans `config/` (voir l'[arborescence](#arborescence-du-dépôt)).

---

## 1. But du TP en une phrase

On installe un serveur **Rocky Linux 9.8** et, **pendant l'installation**, on lui ajoute tout ce qu'il faut pour devenir un **hyperviseur KVM**. Ensuite, on prouve qu'il fonctionne en y créant une petite machine virtuelle (**CirrOS**).

---

## 2. La théorie avant de commencer

### 2.1 Qu'est-ce qu'un hyperviseur ?

Un **hyperviseur** est un logiciel qui permet de faire tourner **plusieurs ordinateurs virtuels** (des **VM**, *Virtual Machines*) sur **un seul ordinateur physique**.

> 🏢 **Analogie** : un immeuble.
> L'ordinateur physique, c'est le terrain et le bâtiment.
> L'hyperviseur, c'est le **gérant de l'immeuble** : il découpe le bâtiment en appartements (les VM) et donne à chacun un peu d'électricité (le CPU), d'eau (la RAM) et de place à la cave (le disque).
> Chaque locataire croit avoir sa propre maison, mais en réalité tout le monde partage le même bâtiment.

Il existe deux grandes familles :

| Type | Où il s'installe | Exemples |
|---|---|---|
| **Type 1** (« bare metal », sur le métal nu) | Directement sur le matériel, sans autre système en dessous | VMware ESXi, **KVM**, Hyper-V |
| **Type 2** (« hébergé ») | Comme un logiciel normal, dans Windows, macOS ou Linux | VMware Workstation, VirtualBox |

### 2.2 Qu'est-ce que KVM ?

**KVM** (*Kernel-based Virtual Machine*, « machine virtuelle basée sur le noyau ») est un **module du noyau Linux**. Une fois ce module chargé, **Linux lui-même devient un hyperviseur de type 1**.

KVM ne travaille jamais seul. On utilise toujours une petite équipe d'outils :

| Outil | Rôle | Analogie |
|---|---|---|
| **KVM** (module du noyau) | Utilise les instructions spéciales du processeur (Intel VT-x / AMD-V) pour faire tourner les VM vite | Le moteur de la voiture |
| **QEMU** (`qemu-kvm`) | Fabrique le « faux matériel » de la VM (carte réseau, disque, carte graphique…) | La carrosserie et le tableau de bord |
| **libvirt** (services `virtqemud`, `virtnetworkd`…) | Une interface commune pour gérer les VM (démarrer, arrêter, lister, réseaux…) | Le garagiste qui s'occupe de toutes les voitures |
| **virsh** | La commande en ligne pour parler à libvirt | Le téléphone pour appeler le garagiste |
| **virt-install** | La commande pour créer une nouvelle VM | Le bon de commande d'une nouvelle voiture |

### 2.3 Accélération matérielle et émulation : la notion la plus importante de ce TP

Pour aller vite, KVM a besoin que le processeur possède des **instructions de virtualisation** :
- **VT-x** chez Intel (le drapeau `vmx` dans `/proc/cpuinfo`) ;
- **AMD-V** chez AMD (le drapeau `svm`).

Quand ces instructions sont présentes, le fichier spécial **`/dev/kvm`** existe, et les VM tournent presque à la vitesse du vrai processeur.

Quand elles **ne sont pas présentes**, QEMU peut quand même faire tourner la VM, mais **en émulation** : il **traduit chaque instruction** une par une. Ce mode s'appelle **TCG** (*Tiny Code Generator*).

> 🗣️ **Analogie** : parler avec un étranger.
> - **KVM (accéléré)** : vous parlez la même langue, la conversation est rapide.
> - **QEMU TCG (émulé)** : un traducteur répète chaque phrase. Ça marche, mais c'est beaucoup plus lent.

### 2.4 Pourquoi on est en émulation dans ce TP

Notre Rocky Linux n'est pas installé sur un vrai PC : il est **dans une VM VMware Workstation**, elle-même sur Windows 11. On fait donc de la **virtualisation imbriquée** (*nested virtualization*) : une VM (CirrOS) dans une VM (Rocky) dans un PC (Windows).

```
PC physique
└── Windows 11 (avec sa propre couche Hyper-V / VBS active)
    └── VMware Workstation
        └── VM « kvm-rocky » (Rocky Linux 9.8 + KVM/libvirt)
            └── VM « cirros-test » (CirrOS)
```

Pour que KVM soit accéléré dans `kvm-rocky`, il faudrait que VMware **transmette** VT-x à la VM (case « Virtualiser Intel VT-x/EPT »). Or, sur ce PC, **Windows garde VT-x pour lui** : la **VBS** (*Virtualization-Based Security*, sécurité basée sur la virtualisation) et l'**Intégrité de la mémoire** utilisent l'hyperviseur de Windows. Il a été décidé de **ne pas désactiver ces protections de Windows**. Donc :

- la VM VMware a `vhv.enable = "FALSE"` (pas de VT-x imbriqué) ;
- dans Rocky, `/dev/kvm` n'existe pas ;
- les VM créées dans Rocky tournent avec `--virt-type qemu` (émulation TCG).

C'est **exactement la même situation que dans le TP OpenStack**, où Nova utilisait `virt_type = qemu`. Le TP reste valide : on installe bien toute la pile KVM/libvirt et on fait tourner une VM. Seule la vitesse est réduite.

### 2.5 Le kickstart : répondre à l'installateur à l'avance

L'installateur de Rocky / RHEL s'appelle **Anaconda**. Normalement, il pose des questions : langue, clavier, disque, mot de passe, logiciels…

Un fichier **kickstart** (`ks.cfg`) contient **toutes les réponses à l'avance**. L'installation se fait alors toute seule, sans clic.

> 📝 **Analogie** : un formulaire déjà rempli qu'on donne au guichet. L'employé n'a plus besoin de vous poser de questions.

Astuce utilisée ici : si Anaconda trouve un disque ou un CD dont le **nom de volume est `OEMDRV`**, il va **automatiquement** y chercher un fichier `ks.cfg`. On a donc mis `ks.cfg` dans une petite ISO nommée `OEMDRV`, insérée comme 2ᵉ lecteur CD de la VM. Pas besoin de taper quoi que ce soit au démarrage.

### 2.6 Le groupe « Virtualization Host »

La documentation Red Hat demande d'installer KVM **pendant l'installation**, en choisissant l'environnement logiciel **« Virtualization Host »** (« Hôte de virtualisation » en français). Dans un kickstart, cela s'écrit :

```
@^virtualization-host-environment
```

- `@` veut dire « un groupe de paquets » ;
- `^` veut dire « un **environnement** » (un groupe de groupes, c'est-à-dire le profil complet de la machine).

Cet environnement installe notamment `qemu-kvm`, `libvirt` et les outils associés.

---

## 3. Le matériel et les logiciels utilisés

| Élément | Valeur |
|---|---|
| PC hôte | Windows 11 Pro, clavier suisse romand |
| Hyperviseur de type 2 | VMware Workstation Pro **25.0.1** (interface en français) |
| Outils VMware en ligne de commande | `vmrun.exe`, `vmware-vdiskmanager.exe` dans `C:\Program Files (x86)\VMware\VMware Workstation\` |
| ISO | `Rocky-9.8-x86_64-dvd.iso` (14,15 Go), stockée dans `D:\VM\` |
| VM | `kvm-rocky` dans `D:\VMs\kvm-rocky\` : 4 vCPU, 8 Go RAM, disque 60 Go, réseau NAT (VMnet8), UEFI |
| Système invité | Rocky Linux 9.8 (Blue Onyx), noyau 5.14.0-687 |
| Paquets KVM | `qemu-kvm-10.1.0`, `libvirt-11.10.0`, `virt-install-5.1.0` |
| VM de test | CirrOS 0.6.3 (image de 21 Mo prévue pour les tests) |

---

## 4. Schéma de l'architecture

```
                  Internet
                     │
┌────────────────────┴─────────────────────────────────────────────┐
│ PC Windows 11  (VMware Workstation 25)                           │
│                                                                  │
│   Réseau NAT VMnet8 : 192.168.190.0/24                           │
│   ┌───────────────────────────────────────────────────────────┐  │
│   │ VM kvm-rocky  — Rocky Linux 9.8 — 192.168.190.145 (ens160)│  │
│   │   KVM / QEMU / libvirt                                    │  │
│   │                                                           │  │
│   │   Réseau libvirt « default » (NAT) : 192.168.122.0/24     │  │
│   │   pont virbr0 = 192.168.122.1                             │  │
│   │   ┌─────────────────────────────────────────────┐         │  │
│   │   │ VM cirros-test — CirrOS 0.6.3               │         │  │
│   │   │ 192.168.122.168 (eth0), 1 vCPU, 256 Mo      │         │  │
│   │   └─────────────────────────────────────────────┘         │  │
│   └───────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

On a **deux NAT l'un dans l'autre** :
1. VMware fait du NAT pour `kvm-rocky` (réseau VMnet8) ;
2. libvirt fait du NAT pour `cirros-test` (réseau `default`, pont `virbr0`).

> 📦 **Analogie du NAT** : une boîte aux lettres collective. Toutes les VM de l'intérieur sortent sur Internet avec **l'adresse de l'immeuble**. Le routeur note qui a envoyé quoi pour redistribuer les réponses.

---

## Étape 0 – Vérifier l'état de Windows

**Pourquoi ?** Pendant la semaine, des réglages de sécurité Windows avaient été modifiés pour essayer d'activer la virtualisation imbriquée. On vérifie, **sans rien modifier**, qu'ils sont revenus à la normale.

Commandes (PowerShell) :

```powershell
# Valeur 1 = VBS activée
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard |
    Select EnableVirtualizationBasedSecurity

# Valeur 1 = protection de Windows Hello par la VBS activée
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello |
    Select Enabled

# Valeur 1 = Intégrité de la mémoire (HVCI) activée
Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity |
    Select Enabled

# 2 = VBS activée ET en cours d'exécution
(Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus

# True = l'hyperviseur de Windows est chargé
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent
```

Explications :
- `Get-ItemProperty` lit une valeur dans le **registre** (la grande base de réglages de Windows). On lit seulement, on n'écrit rien.
- `HKLM:` = *HKEY_LOCAL_MACHINE*, les réglages qui concernent toute la machine.
- `Get-CimInstance` interroge **WMI/CIM**, la base d'informations système de Windows.

Résultat : **tout est revenu à la normale** (VBS = 1, Windows Hello = 1, Intégrité de la mémoire = 1, VBS en cours d'exécution = 2, hyperviseur présent = True).

![Etat de Windows](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/03-windows-retour-normal.png)

Deux autres vérifications demandent un PowerShell **en administrateur** (clic droit sur le menu Démarrer → **Terminal (administrateur)**) :

```powershell
bcdedit /enum "{current}" | findstr /i hypervisor   # options de démarrage de Windows
Get-BitLockerVolume C: | Select ProtectionStatus    # chiffrement du disque C:
```

- `bcdedit` lit la configuration de démarrage de Windows ; `| findstr /i hypervisor` ne garde que les lignes qui contiennent « hypervisor ». `hypervisorlaunchtype Auto` veut dire que l'hyperviseur de Windows démarre normalement.
- `Get-BitLockerVolume` lit l'état de **BitLocker** (le chiffrement du disque). `ProtectionStatus On` = le disque C: est bien protégé.

Résultat : `hypervisorlaunchtype Auto` et BitLocker `On` ✅.

![bcdedit et BitLocker](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/03b-windows-admin-bcdedit-bitlocker.png)

---

## Étape 1 – Vérifier l'ISO de Rocky Linux

**Pourquoi ?** Un fichier de 14 Go peut être abîmé pendant le téléchargement, ou modifié par quelqu'un de malveillant. On calcule son **empreinte SHA256** et on la compare à celle publiée par Rocky Linux.

> 🔏 **Analogie** : l'empreinte digitale d'un fichier. Si un seul octet change, l'empreinte change complètement.

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'D:\VM\Rocky-9.8-x86_64-dvd (1).iso'
```

- `Get-FileHash` calcule l'empreinte ;
- `-Algorithm SHA256` choisit l'algorithme (le même que celui de Rocky) ;
- `-LiteralPath` lit le chemin **tel quel** : c'est utile ici, car le nom contient des parenthèses `(1)`, que PowerShell pourrait sinon mal interpréter.

Empreinte officielle : https://download.rockylinux.org/pub/rocky/9.8/isos/x86_64/CHECKSUM

| | SHA256 |
|---|---|
| Calculé | `d2bcbb64c2d67511adf80d40cd9543391a33aea5860a355b1d26d7f55236d01f` |
| Officiel | `d2bcbb64c2d67511adf80d40cd9543391a33aea5860a355b1d26d7f55236d01f` |

✅ Identiques : l'ISO est intacte.

![Checksum ISO](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/04-iso-checksum.png)

---

## Étape 2 – Écrire le fichier kickstart (installation automatique)

### 2.1 Préparer une clé SSH (sur Windows)

**Pourquoi ?** Pour se connecter au serveur **sans taper de mot de passe**, de façon plus sûre.

> 🔑 **Analogie** : un cadenas et sa clé.
> La **clé publique** (`kvm_rocky_key.pub`) est le cadenas : on peut la donner à tout le monde, et on la pose sur le serveur.
> La **clé privée** (`kvm_rocky_key`) est la seule clé qui ouvre ce cadenas : elle **ne quitte jamais le PC** et ne doit **jamais** être publiée.

```bash
ssh-keygen -t ed25519 -N "" -C "lami@kvm-rocky" -f "$USERPROFILE/.ssh/kvm_rocky_key"
```

- `-t ed25519` : type de clé moderne, courte et sûre ;
- `-N ""` : pas de phrase de passe (acceptable pour un TP, à éviter en production) ;
- `-C` : un commentaire pour reconnaître la clé ;
- `-f` : le fichier où enregistrer la clé.

### 2.2 Hacher le mot de passe

Dans le kickstart, on ne met **pas** le mot de passe en clair, mais son **hash** (une empreinte à sens unique, de type SHA-512).

```bash
openssl passwd -6
```

`-6` = format SHA-512 utilisé par Linux (le hash commence par `$6$`).

### 2.3 Le fichier `ks.cfg`

Version publiable (le hash est masqué) : [`config/ks-publiable.cfg`](https://github.com/L4ami/TP-kvm-rocky-linux/blob/main/config/ks-publiable.cfg)

```
text                      # installation en mode texte (pas d'interface graphique)
cdrom                     # les paquets viennent du DVD Rocky
eula --agreed             # accepter la licence
firstboot --disable       # pas d'assistant au premier démarrage

lang fr_FR.UTF-8                                # langue française
keyboard --vckeymap=ch-fr --xlayouts='ch (fr)'  # clavier suisse romand
timezone Europe/Zurich --utc                    # fuseau horaire

network --bootproto=dhcp --device=link --activate --onboot=yes --hostname=kvm-rocky

zerombr                   # effacer l'ancienne table de partitions
clearpart --all --initlabel
autopart                  # partitionnement automatique (LVM : /, /home, swap, /boot)

rootpw --lock             # compte root verrouillé : on passe par sudo
user --name=lami --groups=wheel --iscrypted --password=<MOT_DE_PASSE_MASQUE>
sshkey --username=lami "ssh-ed25519 AAAA... lami@kvm-rocky"

services --enabled=sshd

%packages --ignoremissing
@^virtualization-host-environment   # <- l'environnement "Hôte de virtualisation" = KVM
open-vm-tools                       # outils VMware (permet à VMware de connaître l'IP)
virt-install                        # commande pour créer des VM
guestfs-tools                       # outils pour inspecter/modifier des images disque
%end

reboot                    # redémarrer à la fin
```

Points à comprendre :
- `--device=link` : utiliser la première carte réseau **branchée** ;
- `--groups=wheel` : le groupe **wheel** donne le droit d'utiliser `sudo` (devenir administrateur pour une commande) ;
- `--iscrypted` : le mot de passe donné est déjà un hash ;
- `sshkey` : dépose la clé publique dans `/home/lami/.ssh/authorized_keys` ;
- `--ignoremissing` : si un paquet manque sur le DVD, l'installation continue au lieu de s'arrêter.

![Kickstart](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/05-kickstart-ks-cfg.png)

### 2.4 Mettre `ks.cfg` dans une ISO « OEMDRV »

Script : [`config/make-oemdrv-iso.ps1`](https://github.com/L4ami/TP-kvm-rocky-linux/blob/main/config/make-oemdrv-iso.ps1). Il utilise **IMAPI2**, le moteur de gravure intégré à Windows :
- `IMAPI2FS.MsftFileSystemImage` crée une image de CD vide ;
- `VolumeName = "OEMDRV"` donne au CD le nom magique qu'Anaconda recherche ;
- `Root.AddTree(...)` ajoute le contenu du dossier ;
- un petit morceau de C# recopie le flux produit dans le fichier `oemdrv.iso`.

Résultat : `D:\VMs\kvm-rocky\oemdrv.iso`, 52 Ko.

---

## Étape 3 – Créer la VM dans VMware et lancer l'installation

### 3.1 Le disque virtuel

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmware-vdiskmanager.exe" `
    -c -s 60GB -a lsilogic -t 0 "D:\VMs\kvm-rocky\kvm-rocky.vmdk"
```

- `-c` = créer ; `-s 60GB` = taille maximale ;
- `-a lsilogic` = type de contrôleur d'origine (le disque est ensuite branché en NVMe dans le `.vmx`) ;
- `-t 0` = un seul fichier qui **grossit au fur et à mesure** (il ne prend pas 60 Go tout de suite).

### 3.2 Le fichier de configuration `.vmx`

Le `.vmx` est la « fiche technique » de la VM. Copie : [`config/kvm-rocky.vmx`](https://github.com/L4ami/TP-kvm-rocky-linux/blob/main/config/kvm-rocky.vmx). Lignes importantes :

| Ligne | Signification |
|---|---|
| `guestOS = "rhel9-64"` | VMware optimise pour RHEL 9 64 bits |
| `firmware = "efi"` | démarrage UEFI (moderne) |
| `numvcpus = "4"`, `memsize = "8192"` | 4 processeurs virtuels, 8 Go de RAM |
| `vhv.enable = "FALSE"` | **pas** de VT-x transmis à la VM (voir la théorie 2.4) |
| `nvme0:0.fileName = "kvm-rocky.vmdk"` | le disque de 60 Go sur un contrôleur NVMe |
| `sata0:0.fileName = "...Rocky-9.8...iso"` | CD n°1 = DVD d'installation |
| `sata0:1.fileName = "...oemdrv.iso"` | CD n°2 = le kickstart |
| `ethernet0.connectionType = "nat"` | réseau NAT (VMnet8) |
| `ethernet0.virtualDev = "vmxnet3"` | carte réseau virtuelle performante de VMware |

![Parametres VM](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/06-vm-vmware-parametres.png)

### 3.3 Démarrer la VM

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws start "D:\VMs\kvm-rocky\kvm-rocky.vmx" gui
```

- `vmrun` pilote VMware en ligne de commande ;
- `-T ws` = cible **W**ork**s**tation ;
- `gui` = ouvrir la fenêtre (la VM apparaît aussi dans la bibliothèque VMware).

Le menu GRUB s'affiche et démarre tout seul après 60 secondes sur **« Test this media & install Rocky Linux 9.8 »**. Ce choix vérifie d'abord le DVD (environ 5 minutes), puis Anaconda trouve l'ISO `OEMDRV` et installe **sans aucune question**. 832 paquets ont été installés.

![Installation Anaconda](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/07-installation-anaconda.png)

Après le redémarrage automatique, l'écran de connexion apparaît :

![Installation terminee](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/08-installation-terminee.png)

⏱️ Durée totale : environ **12 minutes** (de 17:17 à 17:29).

---

## Étape 4 – Se connecter en SSH et vérifier KVM

### 4.1 Trouver l'IP et se connecter

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws getGuestIPAddress D:\VMs\kvm-rocky\kvm-rocky.vmx
# 192.168.190.145

ssh -i $env:USERPROFILE\.ssh\kvm_rocky_key lami@192.168.190.145
```

- `getGuestIPAddress` fonctionne grâce à `open-vm-tools` installé dans Rocky ;
- `ssh -i` = utiliser cette clé privée ;
- `lami@192.168.190.145` = utilisateur `lami` sur cette machine.

Aucun mot de passe n'est demandé : la clé SSH fonctionne.

![SSH depuis Windows](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/09-ssh-depuis-windows.png)

### 4.2 Version et environnement installé

```bash
cat /etc/rocky-release          # quelle version de Rocky ?
dnf group list --installed      # quels groupes / environnements sont installés ?
```

Résultat : `Rocky Linux release 9.8 (Blue Onyx)` et l'environnement **« Hôte de virtualisation »**. ✅ KVM a bien été installé **pendant** l'installation.

![Version et groupes](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/10-rocky-version-groupes.png)

### 4.3 Les paquets KVM

```bash
rpm -q qemu-kvm libvirt virt-install guestfs-tools open-vm-tools
```

`rpm -q` (*query*) demande si un paquet est installé et dans quelle version.

```
qemu-kvm-10.1.0-17.el9_8.x86_64
libvirt-11.10.0-12.el9.x86_64
virt-install-5.1.0-1.el9.noarch
guestfs-tools-1.52.2-6.el9.x86_64
open-vm-tools-13.0.10-1.el9.x86_64
```

Les 5 paquets demandés dans le kickstart sont bien là.

![Paquets](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/11-paquets-kvm-libvirt.png)

### 4.4 Le service libvirt et l'accélération matérielle

```bash
systemctl status virtqemud --no-pager
systemctl is-enabled virtqemud.socket virtnetworkd.socket
ls -l /dev/kvm
lsmod | grep kvm
grep -cE 'vmx|svm' /proc/cpuinfo
```

- `virtqemud` est le service libvirt qui gère les VM QEMU/KVM. Il est **activé par socket** : il démarre quand quelqu'un l'appelle et s'arrête tout seul après 120 secondes d'inactivité (option `--timeout 120`). Voir « inactive (dead) » quand aucune VM ne tourne est donc **normal**.
- `lsmod` liste les modules chargés dans le noyau : **aucune ligne `kvm`**.
- `grep -c 'vmx|svm' /proc/cpuinfo` compte les processeurs qui annoncent VT-x/AMD-V : **0**.
- `/dev/kvm` **n'existe pas**.

➡️ C'est la preuve que la VM n'a pas de VT-x : on est en **émulation QEMU**, comme prévu (théorie 2.4).

![Service libvirt](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/12-libvirt-service.png)

### 4.5 `virt-host-validate`

```bash
sudo virt-host-validate qemu
```

Cet outil fait un **bilan de santé** de l'hôte de virtualisation :

| Test | Résultat | Explication |
|---|---|---|
| hardware virtualization | **ÉCHEC** | pas de VT-x dans la VM (attendu) ; les VM tourneront en émulation |
| `/dev/vhost-net`, `/dev/net/tun` | PASS | les périphériques réseau virtuels sont prêts |
| cgroups (cpu, memory, …) | PASS | Linux peut limiter le CPU et la RAM de chaque VM |
| IOMMU | WARN | pas de passage direct de matériel (inutile ici) |
| secure guest (SEV/TDX) | WARN | pas de chiffrement mémoire des VM (inutile ici) |

![virt-host-validate](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/13-virt-host-validate.png)

### 4.6 libvirt répond et le réseau `default` existe

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
```

- `-c qemu:///system` : se connecter au libvirt **du système** (celui qui gère les VM « officielles » de la machine) ;
- `list --all` : toutes les VM, même éteintes (aucune pour l'instant) ;
- `net-list --all` : les réseaux virtuels. Le réseau **`default`** est **actif** et démarre **automatiquement**. C'est un réseau NAT `192.168.122.0/24` avec un serveur DHCP.

![virsh reseau default](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/14-virsh-reseau-default.png)

---

## Étape 5 – Créer une VM de test (CirrOS) dans KVM

**CirrOS** est un Linux minuscule (21 Mo) fait pour **tester** des plateformes de virtualisation. C'est la même image que celle utilisée dans le TP OpenStack.

### 5.1 Télécharger et vérifier l'image

```bash
sudo curl -L -o /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img \
     https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
sudo qemu-img info /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img
sudo md5sum /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img
```

- `/var/lib/libvirt/images` : le dossier standard des disques de VM (SELinux y autorise libvirt) ;
- `curl -L -o` : télécharger, suivre les redirections (`-L`), enregistrer dans un fichier (`-o`) ;
- `qemu-img info` : format `qcow2`, taille virtuelle 112 Mo, taille réelle 20,7 Mo ;
- `md5sum` : `87617e24a5e30cb3b87fda8c0764838f`, identique au fichier `MD5SUMS` officiel ✅.

> 💡 **qcow2** (*QEMU Copy-On-Write v2*) est le format de disque de QEMU/KVM. C'est l'équivalent du **VMDK** de VMware. Il ne prend que la place réellement utilisée.

### 5.2 Choisir l'`os-variant`

```bash
osinfo-query os | grep -i cirros
```

La base `osinfo` connaît CirrOS jusqu'à **0.5.2**. On prend donc **`cirros0.5.2`**, la plus proche. Ce réglage sert à libvirt à choisir de bons pilotes et des valeurs par défaut adaptées.

### 5.3 Créer la VM

```bash
virt-install \
    --connect qemu:///system \
    --name cirros-test \
    --import \
    --disk path=/var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img,format=qcow2,bus=virtio \
    --virt-type qemu \
    --memory 256 \
    --vcpus 1 \
    --os-variant cirros0.5.2 \
    --network network=default \
    --graphics none \
    --noautoconsole
```

| Option | Signification |
|---|---|
| `--name cirros-test` | nom de la VM |
| `--import` | le disque contient **déjà** un système : pas d'installation, on démarre directement dessus |
| `--disk ...,bus=virtio` | le disque, branché en **virtio** (pilote paravirtualisé rapide) |
| `--virt-type qemu` | **émulation** QEMU/TCG, car `/dev/kvm` est absent (avec VT-x, on mettrait `kvm`) |
| `--memory 256` | 256 Mo de RAM |
| `--vcpus 1` | 1 processeur virtuel |
| `--network network=default` | branchée sur le réseau NAT `default` de libvirt |
| `--graphics none` | pas d'écran graphique : on utilisera la console texte (port série) |
| `--noautoconsole` | ne pas ouvrir la console automatiquement (la commande rend la main tout de suite) |

> ℹ️ Le message `WARNING **: Entity http://pcisig.com/pci/1af4/1012 referenced but not defined` vient de la base `osinfo` : elle cite un identifiant de périphérique virtio qu'elle ne décrit pas elle-même. Il est **sans conséquence** ; la ligne « Création de domaine terminée » confirme que la VM est créée.

![virt-install](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/15-cirros-virt-install.png)

### 5.4 La VM tourne

```bash
virsh list --all
virsh dominfo cirros-test
```

`cirros-test` est **en cours d'exécution**. Détail intéressant dans `dominfo` : l'étiquette SELinux est **`svirt_tcg_t`**. « tcg » confirme encore une fois l'**émulation**. Avec KVM accéléré, ce serait `svirt_t`.

> 🛡️ **sVirt** : SELinux enferme chaque VM dans sa propre « bulle » (les nombres `c751,c1001` sont uniques à cette VM). Une VM piratée ne peut pas lire les disques des autres.

![virsh list running](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/16-virsh-list-running.png)

### 5.5 Son adresse IP et un ping depuis Rocky

```bash
virsh domifaddr cirros-test
virsh net-dhcp-leases default
ping -c 4 $(virsh -c qemu:///system domifaddr cirros-test | grep -oE "192\.168\.122\.[0-9]+")
```

- `domifaddr` : les adresses des cartes réseau de la VM ;
- `net-dhcp-leases default` : les adresses distribuées par le DHCP du réseau `default` ;
- `ping -c 4 $(...)` : envoyer 4 paquets de test à l'adresse trouvée par `domifaddr` (`$(...)` remplace la commande par son résultat).

IP de CirrOS : **192.168.122.168** ; ping : **4 envoyés, 4 reçus, 0 % de perte** ✅.

> ℹ️ `net-dhcp-leases` montre aussi une ancienne adresse (192.168.122.105) : c'est le bail DHCP de la première VM CirrOS, supprimée puis recréée pour la capture 15. Le bail reste noté jusqu'à son expiration, ce n'est pas une erreur.

![IP et ping](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/17-cirros-ip-ping.png)

### 5.6 Connexion à la console de CirrOS

```bash
virsh console cirros-test
```

On est **dans** la VM CirrOS. On se connecte avec l'utilisateur `cirros` (son mot de passe par défaut est documenté par le projet CirrOS ; il est masqué sur la capture). Pour quitter la console : **Ctrl + ]**.

Commandes lancées dans CirrOS :

```sh
grep PRETTY /etc/os-release      # CirrOS 0.6.3
ip -4 addr show eth0            # 192.168.122.168/24
ip route                        # passerelle par défaut = 192.168.122.1 (virbr0 sur Rocky)
ping -c 2 192.168.122.1         # la passerelle répond
ping -c 2 8.8.8.8               # Internet répond (double NAT : libvirt puis VMware)
```

✅ La VM imbriquée a un réseau qui fonctionne jusqu'à Internet.

![Console CirrOS](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/18-cirros-console.png)

> ⏱️ En émulation, CirrOS a mis environ **4 minutes** à démarrer complètement (elle cherche d'abord un serveur de métadonnées « cloud » qui n'existe pas ici). Avec KVM accéléré, cela prendrait quelques secondes.

---

## Problèmes rencontrés et solutions

| # | Problème | Cause | Solution |
|---|---|---|---|
| 1 | `bcdedit /enum "{current}"` → « Le type d'entrée spécifié n'est pas valide » et `Get-BitLockerVolume` → « Accès refusé » | ces commandes exigent un terminal **administrateur** | non corrigé volontairement (lecture seule) : à relancer dans un terminal administrateur |
| 2 | `Invoke-WebRequest` renvoyait des nombres au lieu du texte de `CHECKSUM` | le serveur envoie le fichier en binaire ; PowerShell 5.1 renvoie alors des octets | décoder avec `[Text.Encoding]::UTF8.GetString($r.Content)` |
| 3 | `vmrun captureScreen` → « opérations d'invité anonyme non autorisées » | cette commande demande un identifiant dans la VM | capturer la fenêtre VMware avec un script Windows (`config/capture-fenetre.ps1`, fonction `PrintWindow`) |
| 4 | `virsh -c qemu:///system list` → « aucun agent polkit disponible pour s'authentifier » | l'utilisateur `lami` n'a pas le droit de gérer libvirt système | ajouter `lami` au groupe **libvirt** : `sudo usermod -aG libvirt lami`, puis se reconnecter |
| 5 | `virtqemud` affiché « inactive (dead) » | service activé par socket, qui s'arrête après 120 s sans client | normal ; vérifié de nouveau pendant qu'une VM tournait → « active (running) » |
| 6 | `virt-host-validate` : « hardware virtualization : ÉCHEC », pas de `/dev/kvm` | pas de VT-x imbriqué (Windows garde VT-x pour la VBS) | choix assumé : `--virt-type qemu` (émulation), comme `virt_type = qemu` dans le TP OpenStack |
| 7 | `osinfo-query` ne connaît pas CirrOS 0.6.3 | base osinfo plus ancienne que l'image | utiliser la variante la plus proche : `cirros0.5.2` |
| 8 | Premier essai de console : CirrOS pas encore prête (« failed 1/20 … request failed ») | démarrage lent en émulation (recherche du service de métadonnées) | attendre que le port 22 de CirrOS soit ouvert, puis relancer la console |

---

## Lien avec les TP ESXi et OpenStack

| Notion | ESXi | OpenStack | **KVM (ce TP)** |
|---|---|---|---|
| Hyperviseur | ESXi (type 1) | KVM/QEMU piloté par Nova | **KVM/QEMU** piloté par libvirt |
| Outil de gestion | interface web / vSphere | Horizon, commande `openstack` | **`virsh`, `virt-install`** (et Cockpit en option) |
| Format de disque | VMDK | qcow2 (dans Glance) | **qcow2** |
| Réseau virtuel | vSwitch, groupes de ports | Neutron | **réseau libvirt `default`** (pont `virbr0` + NAT + DHCP) |
| Stockage | datastore | Cinder / Glance | **pool** `/var/lib/libvirt/images` |
| VM de test | — | CirrOS | **CirrOS** |
| Sans VT-x imbriqué | ne démarre pas les VM 64 bits | `virt_type = qemu` | **`--virt-type qemu`** |

À retenir : **OpenStack utilise KVM et libvirt en dessous**. Ce TP montre la couche qu'OpenStack automatise.

---

## Arborescence du dépôt

```
tp-kvm/
├── README.md                 ← ce document
├── HACKMD.md                 ← ce compte-rendu, version HackMD
├── captures/                 ← captures 03 à 18
├── config/
│   ├── ks-publiable.cfg      ← kickstart (hash du mot de passe masqué)
│   ├── kvm-rocky.vmx         ← configuration de la VM VMware
│   ├── make-oemdrv-iso.ps1   ← crée l'ISO OEMDRV avec IMAPI2
│   ├── verif-kvm.sh          ← commandes de vérification de l'étape 4
│   ├── cirros-console.py     ← se connecte à la console série de CirrOS (sortie dans logs/)
│   ├── cirros-live.py        ← même chose, affiché en direct (capture 18)
│   ├── capture-fenetre.ps1   ← capture la fenêtre VMware en PNG (captures 07, 08)
│   ├── terminal-capture.ps1  ← ouvre une fenêtre PowerShell, lance une commande, la capture
│   └── captures-cmd/         ← les commandes de chaque capture (03.ps1 … 18.ps1)
├── docs/
│   └── fiche-questions-oral.md ← 15 questions/réponses pour réviser
└── logs/                     ← sorties brutes de toutes les commandes
```

Fichiers **volontairement exclus** du dépôt (`.gitignore`) : `config/ks.cfg` et `config/oemdrv/` (ils contiennent le hash du mot de passe), les ISO, les disques `.vmdk` et la **clé privée SSH** (qui reste dans `%USERPROFILE%\.ssh\`).

---

## Glossaire

| Terme | Définition simple |
|---|---|
| **VM** | Ordinateur virtuel, simulé par un logiciel |
| **Hôte / invité** | L'hôte fait tourner les VM ; l'invité est le système dans la VM |
| **Hyperviseur** | Logiciel qui crée et fait tourner les VM |
| **KVM** | Module du noyau Linux qui transforme Linux en hyperviseur |
| **QEMU** | Logiciel qui simule le matériel d'une VM |
| **TCG** | Mode d'émulation de QEMU, sans accélération matérielle (lent) |
| **libvirt** | Couche de gestion commune des VM sous Linux |
| **virsh** | Commande pour piloter libvirt |
| **VT-x / AMD-V** | Instructions du processeur qui accélèrent la virtualisation |
| **Virtualisation imbriquée** | Faire tourner une VM dans une VM |
| **VBS** | Sécurité Windows qui utilise l'hyperviseur de Windows |
| **Kickstart** | Fichier de réponses pour installer RHEL/Rocky automatiquement |
| **Anaconda** | L'installateur de RHEL/Rocky |
| **OEMDRV** | Nom de volume qu'Anaconda inspecte automatiquement pour trouver `ks.cfg` |
| **NAT** | Partage d'une seule adresse vers l'extérieur pour plusieurs machines internes |
| **DHCP** | Service qui donne automatiquement une adresse IP |
| **virbr0** | Le pont réseau (switch virtuel) du réseau libvirt `default` |
| **virtio** | Pilotes « paravirtualisés » rapides pour les disques et le réseau des VM |
| **qcow2** | Format de disque de QEMU/KVM |
| **SSH** | Connexion à distance sécurisée en ligne de commande |
| **Hash** | Empreinte à sens unique d'une donnée (mot de passe, fichier) |
| **SELinux / sVirt** | Sécurité Linux qui isole chaque VM |
| **sudo / wheel** | `sudo` exécute une commande en administrateur ; le groupe `wheel` en donne le droit |
