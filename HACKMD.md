---
title: TP KVM - Rocky Linux 9.8
tags: virtualisation, kvm, libvirt, rocky-linux, rhel
---

> 📁 Dépôt GitHub : https://github.com/L4ami/TP-kvm-rocky-linux

# TP – Installer KVM pendant l'installation de Rocky Linux (clone de RHEL)

> **Auteur :** Lami · **Date :** 28 octobre 2026 · **Semaine :** Virtualisation (TP 3, après ESXi et OpenStack)
> **En une phrase :** on a installé un serveur **Rocky Linux 9.8** et, **pendant l'installation**, on l'a transformé en **hyperviseur KVM**. On a ensuite prouvé que ça marche en y faisant tourner une petite machine virtuelle, **CirrOS**, qui a accès à Internet.

---

## 📌 Comment lire ce document

Ce compte-rendu est écrit pour **quelqu'un qui débute complètement**. Il a deux buts :
1. **comprendre** ce qu'est KVM, à quoi il sert, et pourquoi on fait chaque geste ;
2. **pouvoir tout refaire de zéro, à la main**, en suivant les étapes une par une.

Chaque mot technique est expliqué la première fois qu'il apparaît.

**Les petits symboles :**

| Symbole | Signification |
|---|---|
| 📖 **C'est quoi ?** | la définition d'un mot technique |
| 💼 **Dans la vraie vie** | à quoi ça sert en entreprise |
| 🧠 **À retenir** | le résumé à connaître par cœur |
| ⚠️ **Attention** | un piège à éviter |
| 🔒 **Secret** | une information à ne jamais publier |
| 📸 **Capture** | la preuve en image |

**Chaque étape a toujours la même forme :**

| Bloc | Contenu |
|---|---|
| 🎯 **Objectif** | ce qu'on veut obtenir |
| 🤔 **Pourquoi** | la raison de ce geste |
| 📍 **Où** | sur quelle machine on travaille |
| ⌨️ **Commande / clics** | ce qu'il faut taper ou cliquer |
| 🔍 **Explication** | chaque mot et chaque option, décortiqués |
| ✅ **Ce que tu dois voir** | le vrai résultat obtenu pendant le TP |
| 📸 **Capture** | l'image correspondante |
| 🆘 **Si ça ne marche pas** | les erreurs fréquentes et leur solution |

**Où taper les commandes ?** On travaille sur **trois machines**. Chaque bloc de commandes indique laquelle :

| Repère | Machine | Comment la reconnaître |
|---|---|---|
| 🪟 **PowerShell Windows** | ton vrai PC | la ligne commence par `PS C:\Users\Lami>` |
| 🐧 **Terminal Rocky (SSH)** | la VM `kvm-rocky`, qui porte KVM | la ligne commence par `[lami@kvm-rocky ~]$` |
| 📦 **Console CirrOS** | la petite VM créée **dans** KVM | la ligne commence par `$` |

---

## Sommaire

[TOC]

---

## 0. Le résultat final en un coup d'œil

![Console CirrOS](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/18-cirros-console.png)

Cette capture montre la fin du TP. On est **dans** la petite VM CirrOS, qui tourne **dans** KVM, qui tourne **dans** Rocky Linux, qui tourne **dans** VMware, sur Windows. Depuis CirrOS :
- ✅ on voit son adresse IP : `192.168.122.168` ;
- ✅ elle joint sa passerelle `192.168.122.1` (c'est Rocky) ;
- ✅ elle joint Internet (`8.8.8.8`, un serveur de Google).

| Test | Résultat | Ce que ça prouve |
|---|---|---|
| Profil installé | ✅ « Hôte de virtualisation » | KVM a été installé **pendant** l'installation |
| Paquets | ✅ `qemu-kvm 10.1.0`, `libvirt 11.10.0`, `virt-install 5.1.0` | toute la pile KVM est là |
| Service libvirt | ✅ `virtqemud` actif | le gestionnaire de VM fonctionne |
| Réseau virtuel | ✅ `default` actif (192.168.122.0/24) | les VM auront du réseau |
| VM CirrOS | ✅ `en cours d'exécution` | KVM/QEMU fait bien tourner une VM |
| `ping` depuis Rocky | ✅ 0 % de perte | la VM est joignable |
| Console + `ping 8.8.8.8` | ✅ 0 % de perte | la VM fonctionne et sort sur Internet |
| Accélération VT-x | ⚠️ absente → émulation QEMU | choix assumé (voir la partie 4) |

---

## 1. Objectif du TP

La consigne du formateur : suivre la documentation Red Hat *« Installing KVM with a new Red Hat Enterprise Linux installation »*.

En clair :
1. installer un serveur Linux de la famille Red Hat ;
2. pendant l'installation, choisir le profil qui en fait un **hyperviseur KVM** ;
3. vérifier que KVM est bien installé ;
4. créer une machine virtuelle dans KVM pour prouver que ça marche.

---

## 2. À quoi ça sert dans la vraie vie ?

Avant d'apprendre « comment », regardons « pourquoi ». Chaque outil de ce TP est utilisé **tous les jours** en entreprise.

### 2.1 La virtualisation en général

| | |
|---|---|
| 📖 **C'est quoi ?** | Faire tourner **plusieurs ordinateurs virtuels** (des VM) sur **un seul ordinateur physique**. Analogie : un immeuble découpé en appartements. |
| 🤔 **Dans ce TP** | C'est le sujet de toute la semaine : ESXi, OpenStack, puis KVM. |
| 💼 **En entreprise** | Presque tous les serveurs d'entreprise sont aujourd'hui des VM. Au lieu d'acheter un serveur par application (un pour la messagerie, un pour le site web, un pour la comptabilité…), on achète quelques gros serveurs et on y met des dizaines de VM. On économise du matériel, de la place et de l'électricité. On peut aussi déplacer une VM d'un serveur à l'autre, ou la sauvegarder d'un bloc. Le **cloud** (AWS, Azure, Google Cloud) loue justement des VM. |

### 2.2 KVM

| | |
|---|---|
| 📖 **C'est quoi ?** | Un morceau du **noyau Linux** qui transforme Linux en **hyperviseur**. Analogie : le **moteur** d'une voiture. |
| 🤔 **Dans ce TP** | C'est l'outil à installer et à étudier. |
| 💼 **En entreprise** | KVM est l'un des hyperviseurs les plus utilisés au monde, souvent sans qu'on le voie. Il est **sous le capot** de **Proxmox VE** (très utilisé dans les PME), d'**OpenStack** (le service Nova du TP précédent), de **Red Hat OpenShift Virtualization** et de **Google Compute Engine** (les VM de Google Cloud). Chez **AWS**, l'hyperviseur **Nitro**, qui fait tourner les VM EC2 récentes, est basé sur la technologie KVM. Les **hébergeurs** l'utilisent aussi pour louer des VM (des « VPS »). |

### 2.3 QEMU

| | |
|---|---|
| 📖 **C'est quoi ?** | Le logiciel qui **fabrique le faux matériel** de chaque VM (disque, carte réseau, écran…). Il sait aussi **imiter** un processeur tout seul (l'émulation). Analogie : la **carrosserie** et le tableau de bord. |
| 🤔 **Dans ce TP** | Il fait tourner CirrOS, en émulation, car il n'y a pas de VT-x (partie 4). |
| 💼 **En entreprise** | Il est toujours utilisé **avec** KVM : on parle de « QEMU/KVM ». Les développeurs l'utilisent aussi pour faire tourner des systèmes faits pour **d'autres processeurs** (par exemple, tester un logiciel prévu pour un processeur ARM sur un PC Intel). |

### 2.4 libvirt, virsh et virt-install

| | |
|---|---|
| 📖 **C'est quoi ?** | **libvirt** est un **service** qui gère toutes les VM de la même façon. **virsh** est la commande pour lui parler. **virt-install** est la commande pour créer une VM. Analogie : le **garagiste**, son **téléphone**, et le **bon de commande** d'une nouvelle voiture. |
| 🤔 **Dans ce TP** | On l'utilise pour vérifier KVM, créer CirrOS, la démarrer, lire son IP et ouvrir sa console. |
| 💼 **En entreprise** | libvirt est la « télécommande universelle » des VM sous Linux. **OpenStack** (Nova), **oVirt** et **Cockpit** (l'interface web d'administration de Rocky et RHEL) passent par libvirt. Un **administrateur système** Linux utilise `virsh` au quotidien : lister les VM, en démarrer une, voir pourquoi une autre ne démarre pas… Et `virt-install` sert dans des scripts pour créer des VM automatiquement. |

### 2.5 RHEL et Rocky Linux

| | |
|---|---|
| 📖 **C'est quoi ?** | **RHEL** (*Red Hat Enterprise Linux*) est le Linux **payant** de l'entreprise Red Hat. **Rocky Linux** est sa **copie gratuite** (un « clone ») : mêmes commandes, mêmes logiciels, même installateur. |
| 🤔 **Dans ce TP** | La documentation du formateur est écrite pour RHEL. On utilise Rocky, qui fonctionne exactement pareil, sans licence. |
| 💼 **En entreprise** | RHEL est très répandu dans les grandes entreprises : banques, assurances, industrie, administrations… Elles paient pour avoir un support officiel et des mises à jour garanties pendant 10 ans. Rocky Linux est utilisé pour apprendre, pour les tests, ou en production quand on n'a pas besoin du support payant. Savoir utiliser Rocky, c'est savoir utiliser RHEL. |

### 2.6 Le kickstart

| | |
|---|---|
| 📖 **C'est quoi ?** | Un fichier texte (`ks.cfg`) qui contient **toutes les réponses** de l'installation. Avec lui, l'installation se fait **toute seule**. Analogie : un **formulaire déjà rempli** donné au guichet. |
| 🤔 **Dans ce TP** | On l'a utilisé pour installer Rocky **et** KVM sans aucun clic (méthode B, partie 8). |
| 💼 **En entreprise** | Imagine devoir installer **100 serveurs identiques**. À la main, ce serait 100 fois les mêmes clics, avec des erreurs. Avec un kickstart, on installe les 100 **automatiquement et à l'identique**. Les entreprises le combinent souvent avec un démarrage réseau (PXE) ou avec des outils comme **Red Hat Satellite** ou **Foreman**. |

### 2.7 SSH et les clés

| | |
|---|---|
| 📖 **C'est quoi ?** | **SSH** permet de piloter un serveur **à distance**, en tapant des commandes, à travers une connexion **chiffrée** (illisible pour un espion). Une **paire de clés** remplace le mot de passe. Analogie : un **cadenas** (la clé publique) et sa **clé** (la clé privée). |
| 🤔 **Dans ce TP** | On pilote Rocky depuis PowerShell, sans taper de mot de passe. |
| 💼 **En entreprise** | C'est **l'outil n°1** d'un administrateur Linux : les serveurs sont dans un datacenter, souvent sans écran. On s'y connecte uniquement en SSH. Les clés sont **plus sûres** que les mots de passe (impossibles à deviner) et permettent d'automatiser (scripts, Ansible…). |

### 2.8 CirrOS

| | |
|---|---|
| 📖 **C'est quoi ?** | Un Linux **minuscule** (21 Mo), fait **exprès pour tester** des plateformes de virtualisation. |
| 🤔 **Dans ce TP** | C'est notre VM de test, déjà vue dans le TP OpenStack. |
| 💼 **En entreprise** | Quand on vient d'installer un hyperviseur ou un cloud, on lance d'abord un CirrOS pour vérifier que les VM démarrent et que le réseau marche. On ne l'utilise **jamais** pour de vraies applications. |

### 2.9 VMware Workstation

| | |
|---|---|
| 📖 **C'est quoi ?** | Un hyperviseur **de type 2** : un logiciel qu'on installe dans Windows pour y créer des VM. |
| 🤔 **Dans ce TP** | Il nous sert de **bac à sable** : notre « serveur » Rocky est une VM VMware. |
| 💼 **En entreprise** | Les techniciens, les développeurs et les formateurs l'utilisent sur leur poste pour tester des systèmes sans risque. Les **serveurs de production**, eux, utilisent des hyperviseurs **de type 1** (ESXi, KVM, Hyper-V). |

### 2.10 ESXi ou KVM : la question du prix

| | **VMware ESXi / vSphere** (TP 1) | **KVM** (ce TP) |
|---|---|---|
| Éditeur | VMware, racheté par **Broadcom** fin 2023 | communauté open source (dans Linux) |
| Prix | **licence payante**, sous forme d'**abonnement** | **gratuit** et **open source** |
| Outils de gestion | vCenter, client web | virsh, Cockpit, Proxmox VE, OpenStack… |

💼 **Pourquoi beaucoup d'entreprises regardent vers KVM depuis 2024 :** après le rachat de VMware par Broadcom, les offres ont changé. Les licences « à vie » ont été remplacées par des **abonnements** vendus en **gros lots**, et de nombreux clients ont vu leur facture augmenter fortement. Beaucoup d'entreprises ont donc étudié ou lancé une migration vers des solutions basées sur **KVM**, comme **Proxmox VE**, **OpenStack** ou **OpenShift Virtualization**. Savoir utiliser KVM est donc une compétence **recherchée**.

🧠 **À retenir (partie 2)**
- KVM est **gratuit**, intégré à Linux, et fait tourner une grande partie du cloud (Google, AWS Nitro, OpenStack, Proxmox).
- **libvirt/virsh** = l'outil quotidien de l'administrateur Linux pour gérer les VM.
- Le **kickstart** sert à installer beaucoup de serveurs identiques sans clic.
- **Rocky** = RHEL gratuit : ce qu'on apprend ici marche en entreprise.

---

## 3. Les bases à comprendre avant de commencer

### 3.1 Machine virtuelle, hôte et invité

📖 **C'est quoi une machine virtuelle (VM) ?**
Un ordinateur, c'est surtout trois choses : un **processeur** (CPU), qui calcule ; de la **mémoire vive** (RAM), qui garde ce qui est en cours ; un **disque**, qui garde les fichiers. Une VM est un **faux ordinateur** fabriqué par un logiciel. Elle a un faux processeur, une fausse RAM et un faux disque (en réalité, un gros fichier). Le système installé dedans **croit** être sur un vrai PC.

📖 **Hôte et invité**
- L'**hôte** (*host*) est la machine qui **fait tourner** les VM.
- L'**invité** (*guest*) est le système **à l'intérieur** d'une VM.

### 3.2 Hyperviseur de type 1 et de type 2

📖 **C'est quoi un hyperviseur ?**
C'est le logiciel qui **crée et fait tourner** les VM. Il partage le vrai processeur, la vraie RAM et le vrai disque entre elles.

> 🏢 **Analogie :** un immeuble. Le bâtiment, c'est le PC. L'hyperviseur, c'est le **gérant** : il découpe le bâtiment en appartements (les VM) et donne à chacun sa part d'électricité (CPU), d'eau (RAM) et de cave (disque).

| | **Type 1** (« bare metal », sur le métal nu) | **Type 2** (« hébergé ») |
|---|---|---|
| Où il s'installe | **directement** sur le matériel, sans Windows en dessous | **comme un logiciel**, dans Windows, macOS ou Linux |
| Analogie | une maison **construite pour** être découpée en appartements | une **tente** montée dans le salon d'une maison existante |
| Pour qui | les serveurs d'entreprise | un poste de travail, les tests, les cours |
| Exemples | ESXi, **KVM**, Hyper-V | VMware **Workstation**, VirtualBox |

**KVM est de type 1** : une fois le module chargé, c'est **Linux lui-même** qui devient l'hyperviseur.

### 3.3 KVM, QEMU, libvirt, virsh, virt-install : comment ils travaillent ensemble

Quand on dit « KVM », on parle d'une **équipe de 5 outils**.

| Outil | Rôle | 🚗 Analogie de la voiture |
|---|---|---|
| **KVM** | module du noyau Linux. Il utilise le « turbo » du processeur (VT-x) pour faire tourner les VM vite. | le **moteur** |
| **QEMU** | fabrique le faux matériel de chaque VM. Sans KVM, il peut aussi imiter le processeur tout seul (lentement). | la **carrosserie** et le tableau de bord |
| **libvirt** (`virtqemud`) | le service qui gère toutes les VM : créer, démarrer, arrêter, lister… | le **garagiste** |
| **virsh** | la commande pour parler à libvirt | le **téléphone** du garagiste |
| **virt-install** | la commande pour créer une nouvelle VM | le **bon de commande** |

**Le chemin d'une commande :**

```
 Toi ──► virsh / virt-install ──► libvirt (virtqemud) ──► QEMU ──► KVM ──► processeur
         (tu tapes)               (le service décide)     (le faux    (le turbo,
                                                           matériel)   s'il existe)
```

On ne parle **presque jamais** directement à QEMU ou à KVM. On parle à **libvirt**, qui s'occupe du reste.

### 3.4 VT-x et l'émulation (TCG)

📖 **C'est quoi VT-x ?**
Les processeurs modernes ont des **instructions spéciales** pour la virtualisation : **VT-x** chez Intel, **AMD-V** chez AMD. C'est le « **turbo** » de la virtualisation : grâce à lui, une VM tourne presque aussi vite qu'un vrai PC.

Sous Linux, le turbo est disponible si :
- le fichier spécial **`/dev/kvm`** existe ;
- le processeur annonce le mot **`vmx`** (Intel) ou **`svm`** (AMD) dans `/proc/cpuinfo` ;
- le module **`kvm_intel`** (ou `kvm_amd`) est chargé.

📖 **C'est quoi l'émulation (TCG) ?**
Sans turbo, QEMU peut quand même faire tourner la VM : il **traduit** chaque instruction du processeur virtuel, une par une. Ce mode s'appelle **TCG** (*Tiny Code Generator*). Ça marche, mais c'est **beaucoup plus lent**.

> 🗣️ **Analogie :** avec turbo, tu parles avec quelqu'un **dans ta langue** : c'est rapide. Sans turbo, un **traducteur** répète chaque phrase : ça marche, mais c'est lent.

Dans `virt-install`, on choisit avec **`--virt-type kvm`** (turbo) ou **`--virt-type qemu`** (émulation).

### 3.5 La virtualisation imbriquée

📖 **C'est quoi ?** Faire tourner une VM **dans** une autre VM. Notre TP est empilé ainsi :

```
PC physique (processeur Intel, avec VT-x)
└── Windows 11  (qui garde VT-x pour sa sécurité)
    └── VMware Workstation  (hyperviseur de type 2)
        └── VM « kvm-rocky » : Rocky Linux + KVM  ← ce qu'on installe
            └── VM « cirros-test » : CirrOS        ← la VM de test
```

Pour que KVM ait le turbo **dans** `kvm-rocky`, VMware devrait lui **prêter** VT-x (la case « Virtualiser Intel VT-x/EPT ou AMD-V/RVI »). La partie 4 raconte pourquoi ce n'est pas possible sur ce PC.

### 3.6 RHEL, Rocky, et pourquoi on ne prend pas RHEL 5

La documentation donnée par le formateur est une **ancienne** documentation Red Hat, de l'époque de RHEL 5 et 6 (années 2009-2010), quand KVM venait d'arriver dans RHEL.

On ne prend **pas** RHEL 5, parce que :
- c'est un système **en fin de vie** : il ne reçoit plus de **mises à jour de sécurité** depuis des années. L'installer, ce serait comme rouler avec une voiture qui n'a plus le droit de passer le contrôle technique ;
- il est fait pour du matériel d'il y a 15 ans ;
- en entreprise, on n'installe **jamais** un système en fin de vie.

Les **principes** de la documentation sont restés les mêmes : on choisit un profil « hôte de virtualisation » pendant l'installation. On applique donc ces principes à une version **moderne** : **Rocky Linux 9.8**, le clone gratuit de **RHEL 9**.

### 3.7 Anaconda, kickstart et l'environnement « Virtualization Host »

📖 **Anaconda** est l'**installateur** de RHEL et de Rocky : le programme qui pose les questions (langue, disque, utilisateur…) et installe le système.

📖 **Un environnement** (ou « profil ») est un **ensemble de logiciels** prévu pour un usage précis. Pendant l'installation, Anaconda propose par exemple « Serveur avec interface graphique », « Serveur », « Installation minimale »… et **« Hôte de virtualisation »** (*Virtualization Host*).

👉 **« Installer KVM pendant l'installation »**, c'est simplement choisir l'environnement **« Hôte de virtualisation »**. Il installe Linux **avec** KVM, QEMU et libvirt.

📖 **Le kickstart** (`ks.cfg`) contient toutes les réponses aux questions d'Anaconda. Dans un kickstart, l'environnement « Hôte de virtualisation » s'écrit **`@^virtualization-host-environment`**.

### 3.8 Les bases du réseau

📖 **Adresse IP** : l'**adresse postale** d'une machine sur le réseau. Exemple : `192.168.190.145`. Elle est faite de 4 nombres de 0 à 255.

📖 **Le « /24 »** (masque de sous-réseau) : il dit quelle partie de l'adresse désigne la **rue** (le réseau) et quelle partie désigne le **numéro de maison** (la machine). `/24` veut dire que les **3 premiers nombres** sont la rue. Donc `192.168.122.0/24` = toutes les adresses de `192.168.122.1` à `192.168.122.254`. Elles sont toutes dans le **même réseau** et peuvent se parler directement.

📖 **Passerelle** : la « **porte de sortie** » du réseau. Pour joindre une adresse d'une **autre** rue (par exemple Internet), une machine envoie ses messages à la passerelle.

📖 **DHCP** : un service qui **donne automatiquement** une adresse IP aux machines qui arrivent sur le réseau. C'est comme l'**accueil d'un camping** qui attribue un emplacement à chaque nouvel arrivant. L'adresse est **prêtée** pour un temps : on parle de **bail** (*lease*).

📖 **NAT** : un **partage d'adresse**. Toutes les machines « de l'intérieur » sortent sur Internet avec l'adresse de la machine du dessus. C'est comme la **boîte aux lettres d'un immeuble** : le facteur ne connaît que l'adresse de l'immeuble, et le concierge redistribue le courrier.

📖 **Pont (*bridge*) `virbr0`** : un **switch virtuel** (une multiprise réseau en logiciel) créé par libvirt dans Rocky. Les VM de KVM s'y « branchent ». Il a l'adresse `192.168.122.1` : c'est la **passerelle** des VM, avec un DHCP et du NAT.

**Notre plan d'adressage :**

| Machine | Réseau | Adresse |
|---|---|---|
| PC Windows (VMware, réseau NAT « VMnet8 ») | 192.168.190.0/24 | passerelle VMware |
| `kvm-rocky` (carte `ens160`) | 192.168.190.0/24 | **192.168.190.145** (donnée par le DHCP de VMware) |
| `virbr0` sur Rocky (réseau libvirt `default`) | 192.168.122.0/24 | **192.168.122.1** |
| `cirros-test` (carte `eth0`) | 192.168.122.0/24 | **192.168.122.168** (donnée par le DHCP de libvirt) |

```
                         Internet
                            │
┌───────────────────────────┴──────────────────────────────────────┐
│ PC Windows 11 + VMware Workstation                               │
│  Réseau NAT VMware « VMnet8 » : 192.168.190.0/24                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ VM kvm-rocky : Rocky Linux 9.8 + KVM   ens160 = .190.145   │  │
│  │  Réseau libvirt « default » : 192.168.122.0/24             │  │
│  │  pont virbr0 = 192.168.122.1 (passerelle + DHCP + NAT)     │  │
│  │  ┌──────────────────────────────────────────┐              │  │
│  │  │ VM cirros-test : CirrOS   eth0 = .122.168│              │  │
│  │  └──────────────────────────────────────────┘              │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

Quand CirrOS va sur Internet, son message passe par **deux NAT** : celui de libvirt (`virbr0`), puis celui de VMware.

### 3.9 SSH et les clés

📖 **SSH** (*Secure Shell*) : une connexion **à distance**, **chiffrée**, pour taper des commandes sur un autre ordinateur.

📖 **La paire de clés SSH :**
- la **clé publique** (fichier `.pub`) est le **cadenas**. On peut la donner à tout le monde. On la pose sur le serveur, dans le fichier `~/.ssh/authorized_keys` (« les clés autorisées ») ;
- la **clé privée** est la **seule clé** qui ouvre ce cadenas. Elle reste sur ton PC.

🔒 **Secret :** la clé privée ne se donne **jamais** et ne se publie **jamais** (ni sur GitHub, ni sur HackMD).

🧠 **À retenir (partie 3)**
- KVM = moteur, QEMU = carrosserie, libvirt = garagiste, virsh = téléphone, virt-install = bon de commande.
- Sans VT-x, pas de turbo : QEMU fonctionne en **émulation (TCG)**, plus lentement.
- « Installer KVM pendant l'installation » = choisir l'environnement **« Hôte de virtualisation »**.
- `/24` = même réseau ; DHCP = adresse automatique ; NAT = adresse partagée ; `virbr0` = switch virtuel des VM.

---

## 4. L'histoire de VT-x sur mon PC

Cette partie raconte **pourquoi** notre KVM tourne sans turbo. C'est une histoire en 6 épisodes.

**Épisode 1 – Le TP ESXi.** Pour faire démarrer les VM dans VMware, il avait fallu **décocher** la case « Virtualiser Intel VT-x/EPT ». VMware ne pouvait pas la proposer sur ce PC.

**Épisode 2 – KVM a besoin de VT-x.** Pour ce TP, on voulait le **turbo** dans la VM Rocky, donc cocher cette case.

**Épisode 3 – Le diagnostic.** On a cherché **qui** gardait VT-x :
- la commande **`systeminfo`** affichait *« Un hyperviseur a été détecté »*. Windows fait donc **déjà** tourner son propre hyperviseur ;
- l'outil **`msinfo32`** (Informations système) montrait que la **sécurité basée sur la virtualisation (VBS)** était active ;
- le **registre** de Windows (clés `DeviceGuard` et `WindowsHello`) confirmait que la VBS et la protection de **Windows Hello** (connexion par code PIN, empreinte ou visage) étaient activées.

📖 **La VBS, c'est quoi ?** Windows 11 utilise lui-même VT-x pour créer une **zone protégée** dans la mémoire. Il y met ses secrets les plus sensibles : identifiants, contrôle des pilotes (*Intégrité de la mémoire*), Windows Hello… Comme Windows garde VT-x pour lui, il ne peut pas le prêter **entièrement** à VMware.

**Épisode 4 – Pourquoi on a arrêté.** Toucher à ces protections, c'était prendre un **risque** pour la **connexion à Windows** (Windows Hello en dépend) et **baisser la sécurité** du PC. Pour un TP, ça ne vaut pas le coup. On a donc décidé de **ne plus toucher** à la sécurité de Windows.

**Épisode 5 – Tout a été remis comme avant.** On l'a vérifié (étape 1 et capture 03b) : VBS active, Windows Hello protégé, Intégrité de la mémoire active, hyperviseur Windows en démarrage automatique, BitLocker actif.

**Épisode 6 – Le choix de l'émulation.** On fait comme dans le **TP OpenStack** (`virt_type = qemu`) : la VM Rocky n'a pas VT-x, et KVM fait tourner ses VM **en émulation** avec **`--virt-type qemu`**. C'est plus lent, mais toute la pile (KVM, libvirt, virsh, virt-install) est installée et utilisée **exactement comme en vrai**.

⚠️ **Attention :** ce document n'explique **pas** comment désactiver la sécurité de Windows, et c'est voulu. En entreprise, on ne baisse jamais la sécurité d'un poste pour un test. Sur un **vrai serveur** KVM (sans Windows en dessous), VT-x est simplement activé dans le BIOS, et ce problème n'existe pas.

🧠 **À retenir (partie 4)** : Windows garde VT-x pour sa sécurité (VBS) → pas de turbo dans la VM → émulation QEMU. C'est un **choix raisonné**, pas une erreur.

---

## 5. Le matériel et les logiciels du TP

| Élément | Valeur |
|---|---|
| PC | Windows 11 Pro, clavier **suisse romand** |
| Logiciel de VM | VMware Workstation Pro **25.0.1** (en français) |
| Système installé | **Rocky Linux 9.8** (« Blue Onyx »), ISO DVD de 14,15 Go |
| VM `kvm-rocky` | 4 processeurs, 8 Go de RAM, disque de 60 Go, réseau NAT, UEFI |
| Paquets KVM | `qemu-kvm 10.1.0`, `libvirt 11.10.0`, `virt-install 5.1.0` |
| VM de test | **CirrOS 0.6.3**, 256 Mo de RAM, 1 processeur |

---

## 6. Étape 1 – Vérifier l'état de Windows

🎯 **Objectif :** vérifier que la sécurité de Windows est intacte.

🤔 **Pourquoi :** on avait fait un diagnostic dans les réglages de sécurité (partie 4). On vérifie que tout est normal. **On ne modifie rien.**

📍 **Où :** 🪟 PowerShell Windows (touche Windows, tape `powershell`, Entrée).

⌨️ **Commandes :**

```powershell
(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard).EnableVirtualizationBasedSecurity
(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello).Enabled
(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity).Enabled
(Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent
```

🔍 **Explication :**
- 📖 Le **registre** est la grande base de réglages de Windows. **`Get-ItemProperty`** **lit** une valeur du registre, sans rien changer.
- **`HKLM:`** = *HKEY_LOCAL_MACHINE*, les réglages de tout l'ordinateur.
- **`( ... ).Nom`** = « lis la clé, puis donne-moi seulement la valeur qui s'appelle *Nom* ».
- **`Get-CimInstance`** demande à Windows ce qui **tourne vraiment** en ce moment (pas seulement ce qui est réglé).

✅ **Ce que tu dois voir :**

| Valeur lue | Résultat | Signification |
|---|---|---|
| EnableVirtualizationBasedSecurity | `1` | la VBS est activée |
| WindowsHello\Enabled | `1` | Windows Hello est protégé par la VBS |
| HypervisorEnforcedCodeIntegrity\Enabled | `1` | l'Intégrité de la mémoire est activée |
| VirtualizationBasedSecurityStatus | `2` | la VBS est activée **et** tourne |
| HypervisorPresent | `True` | l'hyperviseur de Windows est chargé |

📸 **Capture :** `03-windows-retour-normal.png`

![Etat de Windows](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/03-windows-retour-normal.png)

**Deux vérifications de plus**, en 🪟 **PowerShell administrateur** (clic droit sur le bouton Démarrer → **Terminal (administrateur)**) :

```powershell
bcdedit /enum "{current}" | findstr /i hypervisor
Get-BitLockerVolume C: | Select ProtectionStatus
```

🔍 **Explication :**
- **`bcdedit`** affiche les réglages de **démarrage** de Windows. **`/enum "{current}"`** = « montre le démarrage actuel ».
- 📖 Le **`|`** (le « pipe », ou tuyau) envoie le résultat d'une commande à la suivante.
- **`findstr /i hypervisor`** ne garde que les lignes qui contiennent « hypervisor » (`/i` = sans tenir compte des majuscules).
- 📖 **BitLocker** est le **chiffrement du disque** de Windows : sans la bonne clé, le disque est illisible. **`Get-BitLockerVolume C:`** donne son état. **`Select ProtectionStatus`** garde seulement la colonne « protection ».

✅ **Ce que tu dois voir :** `hypervisorlaunchtype    Auto` (l'hyperviseur de Windows démarre normalement) et `ProtectionStatus On` (le disque C: est protégé).

📸 **Capture :** `03b-windows-admin-bcdedit-bitlocker.png`

![bcdedit et BitLocker](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/03b-windows-admin-bcdedit-bitlocker.png)

🆘 **Si ça ne marche pas :** « Accès refusé » ou « Le type d'entrée spécifié n'est pas valide » → le terminal n'est **pas en administrateur**. Rouvre-le avec un clic droit → *Exécuter en tant qu'administrateur*.

---

## 7. Étape 2 – Télécharger et vérifier l'ISO de Rocky Linux

🎯 **Objectif :** avoir le DVD d'installation de Rocky, et être sûr qu'il est intact.

🤔 **Pourquoi :** 📖 une **ISO** est l'image d'un CD ou d'un DVD, dans **un seul fichier**. Celle de Rocky pèse 14 Go. Un fichier peut s'abîmer pendant le téléchargement, ou être modifié par un pirate. On compare donc son **empreinte** avec celle publiée par Rocky.

> 🔏 📖 **Une empreinte (hash)** est l'**empreinte digitale** d'un fichier : une suite de caractères calculée à partir de son contenu. Si un seul octet change, l'empreinte change complètement.

📍 **Où :** 🪟 PowerShell Windows.

⌨️ **Gestes et commande :**
1. Va sur https://rockylinux.org/download, choisis **x86_64** puis l'image **DVD** : `Rocky-9.8-x86_64-dvd.iso`.
2. Calcule l'empreinte (adapte le chemin à **ton** fichier) :

```powershell
(Get-FileHash -Algorithm SHA256 -LiteralPath "D:\VM\Rocky-9.8-x86_64-dvd (1).iso").Hash.ToLower()
```

3. Ouvre https://download.rockylinux.org/pub/rocky/9.8/isos/x86_64/CHECKSUM et cherche la ligne `SHA256 (Rocky-9.8-x86_64-dvd.iso) = ...`.
4. Compare les deux empreintes.

🔍 **Explication :**
- **`Get-FileHash`** calcule l'empreinte d'un fichier (environ 1 minute pour 14 Go).
- **`-Algorithm SHA256`** = la méthode de calcul, la même que celle de Rocky.
- **`-LiteralPath`** = lire le chemin **exactement** tel qu'il est écrit. C'est utile ici, car les parenthèses de `(1)` pourraient être mal comprises par PowerShell.
- **`.Hash.ToLower()`** = garder seulement l'empreinte, en minuscules (comme sur le site).

✅ **Ce que tu dois voir :** la même empreinte des deux côtés :

```
d2bcbb64c2d67511adf80d40cd9543391a33aea5860a355b1d26d7f55236d01f
```

📸 **Capture :** `04-iso-checksum.png`

![Checksum ISO](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/04-iso-checksum.png)

🆘 **Si ça ne marche pas :** les empreintes sont différentes → **n'utilise pas** l'ISO. Supprime-la et retélécharge-la.

---

## 8. Étape 3 – Créer la VM dans VMware Workstation

🎯 **Objectif :** fabriquer l'« ordinateur » qui va recevoir Rocky Linux.

🤔 **Pourquoi :** on n'a pas de vrai serveur. VMware nous en fabrique un virtuel.

📍 **Où :** dans le logiciel **VMware Workstation**.

⌨️ **Clics, un par un :**
1. **Fichier → Nouvelle machine virtuelle…**
2. **Personnalisé (avancé)** → *Suivant*.
3. *Compatibilité matérielle* : laisse la valeur proposée → *Suivant*.
4. **« Je vais installer le système d'exploitation ultérieurement »** → *Suivant*.
5. *Système d'exploitation invité* : **Linux**. *Version* : **Red Hat Enterprise Linux 9 64 bits** → *Suivant*.
6. *Nom* : **`kvm-rocky`**. *Emplacement* : **`D:\VMs\kvm-rocky`** → *Suivant*.
7. *Micrologiciel* : **UEFI** → *Suivant*.
8. *Processeurs* : **1** processeur, **4** cœurs → *Suivant*.
9. *Mémoire* : **8192 Mo** → *Suivant*.
10. *Réseau* : **Utiliser la traduction d'adresses réseau (NAT)** → *Suivant*.
11. *Contrôleur* et *type de disque* : laisse les choix proposés → *Suivant*.
12. **Créer un nouveau disque virtuel** → *Suivant*. Taille : **60 Go**. Coche **« Stocker le disque virtuel dans un seul fichier »**. Ne coche **pas** *« Allouer tout l'espace disque maintenant »* → *Suivant* → *Terminer*.
13. Clic droit sur `kvm-rocky` → **Paramètres…** :
    - **CD/DVD** → *Utiliser un fichier image ISO* → choisis l'ISO Rocky. Coche **Connecter au démarrage**.
    - **Processeurs** → vérifie que **« Virtualiser Intel VT-x/EPT ou AMD-V/RVI »** est **décoché** (voir la partie 4).
    - Si tu utilises la **méthode B** (kickstart) : **Ajouter… → Lecteur CD/DVD** → ISO **`D:\VMs\kvm-rocky\oemdrv.iso`**, **Connecter au démarrage** (voir l'étape 4B).
    - *OK*.

🔍 **Explication des choix :**

| Réglage | Pourquoi |
|---|---|
| Red Hat Enterprise Linux 9 64 bits | Rocky 9 = clone de RHEL 9 : VMware prépare les bons pilotes |
| UEFI | la façon **moderne** de démarrer un PC (remplace l'ancien BIOS) |
| 4 cœurs, 8 Go | KVM va faire tourner des VM **à l'intérieur** : il lui faut de la marge |
| 60 Go, « un seul fichier », non alloué | le fichier du disque commence **petit** et grossit au fur et à mesure |
| NAT | la VM sort sur Internet par l'adresse du PC, et Windows peut lui parler en SSH |
| VT-x **décoché** | Windows ne le prête pas (partie 4) : on travaillera en émulation |

✅ **Ce que tu dois voir :** la VM `kvm-rocky` dans la bibliothèque de VMware.

📸 **Capture :** `06-vm-vmware-parametres.png`. Elle montre le fichier **`.vmx`**, la « **fiche technique** » de la VM que VMware enregistre. On y retrouve chaque réglage :

| Ligne du `.vmx` | Réglage de l'assistant |
|---|---|
| `guestOS = "rhel9-64"` | Red Hat Enterprise Linux 9 64 bits |
| `firmware = "efi"` | UEFI |
| `numvcpus = "4"` / `memsize = "8192"` | 4 cœurs / 8 Go |
| `vhv.enable = "FALSE"` | VT-x **non** transmis à la VM |
| `nvme0:0.fileName = "kvm-rocky.vmdk"` | le disque de 60 Go (fichier `.vmdk`) |
| `sata0:0.fileName` / `sata0:1.fileName` | CD 1 = ISO Rocky, CD 2 = ISO OEMDRV |
| `ethernet0.connectionType = "nat"` | réseau NAT |

![Parametres VM](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/06-vm-vmware-parametres.png)

🆘 **Si ça ne marche pas :** au démarrage, un message dit que VT-x n'est pas pris en charge → décoche la case *Virtualiser Intel VT-x/EPT* dans *Paramètres → Processeurs*.

---

## 9. Étape 4 – Installer Rocky Linux avec KVM : deux méthodes

Il y a deux façons d'arriver au **même résultat** :

| | **Méthode A – à la main** | **Méthode B – automatique (kickstart)** |
|---|---|---|
| Comment | on répond aux écrans d'Anaconda en cliquant | on donne à Anaconda un fichier `ks.cfg` déjà rempli |
| Pour qui | pour apprendre, pour une seule machine | en entreprise, pour beaucoup de machines identiques |
| Dans ce TP | ⚠️ **pas de capture** : le TP a été fait avec la méthode B | ✅ **méthode utilisée** pour les captures |

### 9.1 Méthode A – Installation à la main (celle de la doc Red Hat)

🎯 **Objectif :** installer Rocky en choisissant **« Hôte de virtualisation »**.

📍 **Où :** dans la fenêtre de la VM `kvm-rocky` (VMware), **avec seulement** l'ISO Rocky dans le lecteur.

⌨️ **Clics :**
1. Démarre la VM (triangle vert ▶). Dans le menu noir (**GRUB**, le menu de démarrage), choisis **Install Rocky Linux 9.8** avec les flèches, puis Entrée.
2. **Langue** : *Français* → *Français (Suisse)* → *Continuer*.
3. Écran **Résumé de l'installation** :
   - **Clavier** → ajoute *Suisse (français)* et mets-le en premier ;
   - **Date et heure** → *Europe / Zurich* ;
   - **Destination de l'installation** → clique sur le disque de 60 Go, *Configuration du stockage : Automatique* → *Terminé* ;
   - **Réseau et nom d'hôte** → mets la carte réseau sur **Activé**, *Nom d'hôte* : **`kvm-rocky`** → *Appliquer* → *Terminé* ;
   - ⭐ **Sélection de logiciels** → à gauche, *Environnement de base* : coche **« Hôte de virtualisation »** → *Terminé*. **C'est ce clic qui installe KVM pendant l'installation.**
   - **Mot de passe administrateur (root)** → laisse le compte root **verrouillé** ;
   - **Création de l'utilisateur** → nom **`lami`**, coche **« Faire de cet utilisateur un administrateur »**, choisis un mot de passe → *Terminé*.
4. **Commencer l'installation**. Attends, puis **Redémarrer le système**.

🔍 **Explication :**
- **« Faire de cet utilisateur un administrateur »** met `lami` dans le groupe **`wheel`**. 📖 Ce groupe a le droit d'utiliser **`sudo`** (lancer une commande en administrateur).
- **Root verrouillé** : 📖 `root` est le super-administrateur de Linux. Le verrouiller oblige à passer par `sudo` : chaque action d'administration est alors faite **nommément** et **notée** dans les journaux. C'est plus sûr.

Après l'installation, pose la clé SSH sur le serveur (voir l'étape 5 pour créer la clé) :

```powershell
type $env:USERPROFILE\.ssh\kvm_rocky_key.pub | ssh lami@<IP_DE_LA_VM> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Cette commande envoie le cadenas dans `~/.ssh/authorized_keys` et règle les droits du dossier. Le mot de passe de lami est demandé une dernière fois.

### 9.2 Méthode B – Installation automatique par kickstart (utilisée pour le TP)

La méthode B demande trois préparations sur Windows : la **clé SSH** (étape 5), le **mot de passe haché** (4B-1) et le fichier **`ks.cfg`** (4B-2). Il faut aussi le petit **CD OEMDRV** (4B-3). Fais d'abord l'**étape 5** (clé SSH), puis reviens ici.

#### 4B-1 – Fabriquer le mot de passe « haché »

🎯 **Objectif :** obtenir une version **brouillée** du mot de passe de `lami`.

🤔 **Pourquoi :** on n'écrit **jamais** un mot de passe en clair dans un fichier. 📖 Un **hash** de mot de passe est une transformation **à sens unique** : Linux sait vérifier un mot de passe avec, mais personne ne peut retrouver le mot de passe à partir du hash.

> 🥚 **Analogie :** on fait une omelette avec un œuf, mais on ne refait pas l'œuf avec l'omelette.

📍 **Où :** **Git Bash** sur Windows (installé avec Git ; menu Démarrer → *Git Bash*).

⌨️ **Commande :**

```bash
openssl passwd -6
```

Tape ton mot de passe deux fois. Rien ne s'affiche quand tu tapes : c'est normal.

🔍 **Explication :** **`openssl`** = une boîte à outils de chiffrement ; **`passwd`** = « fabrique un hash de mot de passe » ; **`-6`** = méthode **SHA-512**, celle de Linux.

✅ **Ce que tu dois voir :** une longue ligne qui commence par **`$6$`**.

🔒 **Secret :** ce hash ne va **jamais** sur GitHub. Dans le dépôt, la copie publiée `ks-publiable.cfg` le remplace par `<MOT_DE_PASSE_MASQUE>`.

#### 4B-2 – Écrire le fichier ks.cfg

🎯 **Objectif :** écrire le « formulaire déjà rempli » pour Anaconda.

📍 **Où :** 🪟 Windows, avec le **Bloc-notes**.

⌨️ **Gestes :**
1. Crée le dossier `D:\tp-kvm\config\oemdrv\`.
2. Colle le texte ci-dessous dans le Bloc-notes. Remplace `<COLLE_ICI_TON_HASH>` par le hash de 4B-1, et `<COLLE_ICI_TA_CLE_PUBLIQUE>` par le contenu de `kvm_rocky_key.pub` (étape 5).
3. *Enregistrer sous* `D:\tp-kvm\config\oemdrv\ks.cfg`, avec **Type : Tous les fichiers** (sinon le Bloc-notes ajoute `.txt`).

```
# Kickstart - TP KVM sur Rocky Linux 9.8
text
cdrom
eula --agreed
firstboot --disable

lang fr_FR.UTF-8
keyboard --vckeymap=ch-fr --xlayouts='ch (fr)'
timezone Europe/Zurich --utc

network --bootproto=dhcp --device=link --activate --onboot=yes --hostname=kvm-rocky

zerombr
clearpart --all --initlabel
autopart

rootpw --lock
user --name=lami --groups=wheel --iscrypted --password=<COLLE_ICI_TON_HASH>
sshkey --username=lami "<COLLE_ICI_TA_CLE_PUBLIQUE>"

services --enabled=sshd

%packages --ignoremissing
@^virtualization-host-environment
open-vm-tools
virt-install
guestfs-tools
%end

reboot
```

🔍 **Explication, ligne par ligne :**

| Ligne | Signification |
|---|---|
| `# ...` | un **commentaire** : Anaconda l'ignore |
| `text` | installer en **mode texte** (sans fenêtres) |
| `cdrom` | les logiciels viennent du **DVD** Rocky |
| `eula --agreed` | accepter la **licence** |
| `firstboot --disable` | pas d'assistant au premier démarrage |
| `lang fr_FR.UTF-8` | système en **français** (UTF-8 = l'encodage qui gère les accents) |
| `keyboard --vckeymap=ch-fr --xlayouts='ch (fr)'` | clavier **suisse romand** : `vckeymap` en mode texte, `xlayouts` en mode graphique |
| `timezone Europe/Zurich --utc` | fuseau horaire de la Suisse ; l'horloge interne est en temps universel |
| `network --bootproto=dhcp` | obtenir l'IP **automatiquement** (DHCP) |
| `--device=link` | utiliser la première carte réseau **branchée** |
| `--activate --onboot=yes` | allumer le réseau tout de suite et à chaque démarrage |
| `--hostname=kvm-rocky` | le **nom** de la machine |
| `zerombr` | effacer l'ancienne table de partitions |
| `clearpart --all --initlabel` | supprimer toutes les partitions et repartir d'un disque propre |
| `autopart` | **découper le disque automatiquement** (`/boot`, `/`, `/home`, swap) |
| `rootpw --lock` | **verrouiller** `root` : on passera par `sudo` |
| `user --name=lami --groups=wheel` | créer **lami**, membre de **wheel** (droit de faire `sudo`) |
| `--iscrypted --password=...` | son mot de passe, donné sous forme de **hash** |
| `sshkey --username=lami "..."` | poser la **clé publique** (le cadenas) chez lami |
| `services --enabled=sshd` | démarrer le **serveur SSH** automatiquement |
| `%packages ... %end` | la **liste des logiciels** à installer |
| `--ignoremissing` | si un logiciel manque, continuer au lieu de bloquer |
| ⭐ `@^virtualization-host-environment` | **le profil « Hôte de virtualisation » = la ligne qui installe KVM**. `@` = un groupe de logiciels, `^` = un **environnement** (un profil complet). |
| `open-vm-tools` | les outils VMware dans Linux (VMware voit l'IP de la VM et peut l'arrêter proprement) |
| `virt-install` | la commande pour créer des VM |
| `guestfs-tools` | des outils pour lire ou modifier le disque d'une VM |
| `reboot` | **redémarrer** à la fin |

📸 **Capture :** `05-kickstart-ks-cfg.png` (la version publiable, avec le hash masqué)

![Kickstart](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/05-kickstart-ks-cfg.png)

#### 4B-3 – Le petit CD « OEMDRV »

🎯 **Objectif :** qu'Anaconda **trouve** `ks.cfg` tout seul.

🤔 **Pourquoi :** Anaconda a une règle : au démarrage, il regarde tous les disques et CD. S'il en trouve un dont le **nom de volume** est **`OEMDRV`**, il lit le `ks.cfg` qui est dessus. On fabrique donc un **mini-CD virtuel** (une ISO de 52 Ko) nommé `OEMDRV`, et on le branche dans la VM comme **2ᵉ lecteur CD** (étape 3, point 13).

📍 **Où :** 🪟 PowerShell Windows.

⌨️ **Commandes :**

```powershell
New-Item -ItemType Directory -Force D:\VMs\kvm-rocky
powershell -ExecutionPolicy Bypass -File D:\tp-kvm\config\make-oemdrv-iso.ps1 -Source D:\tp-kvm\config\oemdrv -Output D:\VMs\kvm-rocky\oemdrv.iso
```

🔍 **Explication :**
- **`New-Item -ItemType Directory -Force`** crée le dossier de la VM (`-Force` = pas d'erreur s'il existe déjà).
- **`-ExecutionPolicy Bypass`** : Windows bloque les scripts par défaut. Cette option autorise **ce** script, **une seule fois**.
- **`-File ...make-oemdrv-iso.ps1`** : le script du dépôt. Il utilise **IMAPI2**, le **graveur de CD** intégré à Windows : il crée une image de CD nommée `OEMDRV`, y met le contenu de `-Source` et l'enregistre dans `-Output`.

✅ **Ce que tu dois voir :** `D:\VMs\kvm-rocky\oemdrv.iso`, environ 52 Ko.

> 💡 **Autre possibilité :** taper `inst.ks=` suivi de l'adresse du fichier dans le menu GRUB. L'astuce OEMDRV évite de taper quoi que ce soit.

#### 4B-4 – Lancer l'installation automatique

📍 **Où :** VMware, VM `kvm-rocky` (avec les **2 lecteurs CD** : ISO Rocky + `oemdrv.iso`).

⌨️ **Gestes :**
1. Démarre la VM (▶).
2. Dans le menu **GRUB**, **ne touche à rien** : après 60 secondes, il lance *« Test this media & install Rocky Linux 9.8 »*.
3. Le DVD est d'abord vérifié (environ 5 minutes). Ensuite, Anaconda lit `ks.cfg` et installe **sans poser de question**.
4. La VM redémarre toute seule.

⏱️ Durée totale : environ **12 minutes** (de 17:17 à 17:29).

✅ **Ce que tu dois voir :** les paquets défilent (`Installation de ... (826/832)`), puis la configuration des paquets libvirt :

📸 **Capture :** `07-installation-anaconda.png`

![Installation Anaconda](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/07-installation-anaconda.png)

Après le redémarrage, l'écran de connexion **`kvm-rocky login:`** :

📸 **Capture :** `08-installation-terminee.png`

![Installation terminee](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/08-installation-terminee.png)

🆘 **Si ça ne marche pas :**
- **Anaconda pose des questions au lieu de tout faire seul** → il n'a pas trouvé `ks.cfg`. Vérifie que le 2ᵉ CD est **connecté**, que l'ISO s'appelle bien `OEMDRV` et que le fichier s'appelle `ks.cfg` (pas `ks.cfg.txt`).
- **L'installation s'arrête sur une erreur de kickstart** → une ligne de `ks.cfg` est mal écrite. Le message donne le numéro de la ligne.
- **Pour sauter la vérification du DVD** → dans GRUB, choisis *Install Rocky Linux 9.8* (flèche ↑) puis Entrée.

---

## 10. Étape 5 – Créer une clé SSH

> Cette étape est à faire **avant** la méthode B (le kickstart a besoin de la clé publique), ou **après** la méthode A.

🎯 **Objectif :** créer le **cadenas** (clé publique) et sa **clé** (clé privée).

🤔 **Pourquoi :** pour se connecter au serveur **sans mot de passe** et de façon **plus sûre** (voir 3.9).

📍 **Où :** 🪟 PowerShell Windows.

⌨️ **Commande :**

```powershell
ssh-keygen -t ed25519 -C "lami@kvm-rocky" -f "$env:USERPROFILE\.ssh\kvm_rocky_key"
```

À la question *passphrase*, appuie deux fois sur **Entrée** (pas de phrase de passe : acceptable pour un TP).

🔍 **Explication :**
- **`ssh-keygen`** = le générateur de clés SSH, déjà présent dans Windows 10 et 11.
- **`-t ed25519`** = le **type** de clé : moderne, courte et très sûre.
- **`-C "lami@kvm-rocky"`** = un **commentaire**, pour reconnaître la clé.
- **`-f ...`** = le **fichier** où ranger la clé. **`$env:USERPROFILE`** = ton dossier personnel (`C:\Users\Lami`).

✅ **Ce que tu dois voir :** deux fichiers dans `C:\Users\Lami\.ssh\` :
- `kvm_rocky_key` → 🔒 la **clé privée** ;
- `kvm_rocky_key.pub` → la **clé publique**.

Pour lire la clé publique : `Get-Content "$env:USERPROFILE\.ssh\kvm_rocky_key.pub"`. Elle tient sur une ligne : `ssh-ed25519 AAAAC3Nza... lami@kvm-rocky`.

---

## 11. Étape 6 – Trouver l'IP et se connecter en SSH

🎯 **Objectif :** piloter Rocky depuis PowerShell.

🤔 **Pourquoi :** dans la fenêtre VMware, il n'y a ni copier-coller ni défilement facile. En SSH, on travaille confortablement depuis Windows, comme un vrai administrateur.

📍 **Où :** d'abord la fenêtre VMware (ou 🪟 PowerShell), puis 🪟 PowerShell.

⌨️ **a) Trouver l'adresse IP** (2 façons) :
- **Dans la fenêtre VMware** : connecte-toi (`lami` + ton mot de passe), puis tape `ip -4 addr`. L'IP est sur la ligne `inet` de la carte **`ens160`**.
- **Depuis 🪟 PowerShell**, sans se connecter (grâce à `open-vm-tools`) :

```powershell
& "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe" -T ws getGuestIPAddress D:\VMs\kvm-rocky\kvm-rocky.vmx
```

🔍 **`&`** = « lance ce programme » (obligatoire quand le chemin est entre guillemets) ; **`vmrun`** = l'outil de VMware en ligne de commande ; **`-T ws`** = cible **W**ork**s**tation ; **`getGuestIPAddress`** = « donne l'IP de l'invité ».

Résultat : **`192.168.190.145`**.

⌨️ **b) Se connecter :**

```powershell
ssh -i $env:USERPROFILE\.ssh\kvm_rocky_key lami@192.168.190.145
```

🔍 **Explication :**
- **`ssh`** = se connecter à distance ;
- **`-i`** = utiliser **cette** clé privée (*identity*) ;
- **`lami@192.168.190.145`** = « l'utilisateur **lami**, sur la machine **192.168.190.145** ».

La première fois, SSH demande `Are you sure you want to continue connecting (yes/no)?` → tape **`yes`**. Il retient ainsi l'empreinte du serveur, pour pouvoir détecter plus tard un faux serveur.

✅ **Ce que tu dois voir :** l'invite devient **`[lami@kvm-rocky ~]$`**, **sans** mot de passe demandé.
- `lami` = qui tu es ;
- `kvm-rocky` = sur quelle machine ;
- `~` = ton dossier personnel ;
- `$` = utilisateur normal (`#` = root).

Sur la capture, on a ajouté `hostname` (nom de la machine), `whoami` (« qui suis-je ? »), `id` (mes groupes : on voit **`wheel`** et **`libvirt`**, voir l'étape 8) et `ip -4 -br addr show ens160` (l'IP en version courte : `-br` = *brief*).

📸 **Capture :** `09-ssh-depuis-windows.png`

![SSH depuis Windows](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/09-ssh-depuis-windows.png)

🆘 **Si ça ne marche pas :**
- `Connection timed out` → la VM est éteinte, ou l'IP est fausse.
- `Permission denied (publickey)` → la clé publique n'est pas sur le serveur, ou tu as oublié `-i`.

---

## 12. Étape 7 – Vérifier que KVM est installé

📍 **Où :** toutes les commandes de cette étape se tapent dans 🐧 **le terminal Rocky (SSH)**.

### 12.1 La version et le profil installé

🎯 **Objectif :** prouver que KVM a été installé **pendant** l'installation.

⌨️ **Commandes :**

```bash
cat /etc/rocky-release
dnf group list --installed
```

🔍 **Explication :**
- **`cat`** affiche le contenu d'un fichier. `/etc/rocky-release` contient la version.
- 📖 **`dnf`** est le **gestionnaire de logiciels** de Rocky : il installe, met à jour et liste les logiciels (comme un *App Store* en ligne de commande). **`group list --installed`** = « liste les **groupes** de logiciels installés ». (Sur la capture, `-q`, *quiet*, cache juste les messages de téléchargement.)

✅ **Ce que tu dois voir :**

```
Rocky Linux release 9.8 (Blue Onyx)
Groupes d'environnements installés :
   Hôte de virtualisation
```

👉 **C'est la preuve principale du TP** : l'environnement **« Hôte de virtualisation »** est installé.

📸 **Capture :** `10-rocky-version-groupes.png`

![Version et groupes](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/10-rocky-version-groupes.png)

### 12.2 Les logiciels de KVM

⌨️ **Commande :**

```bash
rpm -q qemu-kvm libvirt virt-install guestfs-tools open-vm-tools
```

🔍 **Explication :** 📖 un **paquet** est un logiciel prêt à installer (un peu comme un `.exe` d'installation). **`rpm`** gère les paquets ; **`-q`** (*query*) = « est-il installé, et en quelle version ? ».

✅ **Ce que tu dois voir :**

```
qemu-kvm-10.1.0-17.el9_8.x86_64        ← QEMU avec le support KVM
libvirt-11.10.0-12.el9.x86_64          ← libvirt
virt-install-5.1.0-1.el9.noarch        ← virt-install
guestfs-tools-1.52.2-6.el9.x86_64
open-vm-tools-13.0.10-1.el9.x86_64
```

`el9` = *Enterprise Linux 9* ; `x86_64` = pour processeur 64 bits ; `noarch` = pour tous les processeurs (c'est un script).

📸 **Capture :** `11-paquets-kvm-libvirt.png`

![Paquets](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/11-paquets-kvm-libvirt.png)

### 12.3 Le service libvirt et le « turbo »

⌨️ **Commandes :**

```bash
systemctl status virtqemud --no-pager -n 0
systemctl is-enabled virtqemud.socket virtnetworkd.socket
ls -l /dev/kvm
lsmod | grep kvm
grep -cE 'vmx|svm' /proc/cpuinfo
```

🔍 **Explication :**
- 📖 Un **service** est un programme qui tourne **en arrière-plan** (comme les services de Windows). **`systemctl`** les gère. **`status virtqemud`** = « dans quel état est le service libvirt pour QEMU ? ». **`--no-pager`** = tout afficher d'un coup ; **`-n 0`** = sans les lignes du journal.
- **`is-enabled ...socket`** = « ce service démarre-t-il automatiquement ? ». `virtnetworkd` est le service libvirt qui gère les **réseaux** virtuels.
- **`ls -l /dev/kvm`** = « est-ce que le fichier du turbo existe ? ».
- **`lsmod`** liste les **modules** (pilotes) chargés dans le noyau. **`| grep kvm`** ne garde que les lignes qui contiennent « kvm ».
- **`grep -cE 'vmx|svm' /proc/cpuinfo`** : cherche `vmx` **ou** `svm` dans la description du processeur. `-E` permet le « ou » (`|`) ; `-c` **compte** les lignes trouvées.

✅ **Ce que tu dois voir :**

| Commande | Résultat | Signification |
|---|---|---|
| `systemctl status virtqemud` | **`active (running)`**, `enabled` | libvirt tourne et démarre au boot |
| `is-enabled` | `enabled` `enabled` | les services VM et réseau démarrent automatiquement |
| `ls -l /dev/kvm` | `Aucun fichier ou dossier de ce type` | **pas de turbo** |
| `lsmod \| grep kvm` | (rien) | le module KVM n'est pas chargé |
| `grep -c vmx/svm` | **`0`** | le processeur de la VM n'annonce pas VT-x |

👉 Ce n'est **pas une panne** : c'est la conséquence de la partie 4. KVM fonctionnera **en émulation**.

> 💡 `virtqemud` est **activé par socket** : il dort quand personne ne l'utilise, se réveille quand on lance `virsh`, et se rendort après 120 secondes sans travail (`--timeout 120`). Le voir `inactive (dead)` quand aucune VM ne tourne est **normal**.

📸 **Capture :** `12-libvirt-service.png`

![Service libvirt](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/12-libvirt-service.png)

### 12.4 Le bilan de santé : virt-host-validate

⌨️ **Commande :**

```bash
sudo virt-host-validate qemu
```

🔍 **Explication :**
- **`sudo`** = lancer la commande **en administrateur**. Il demande **ton** mot de passe (celui de lami). La toute première fois, il affiche un petit rappel des règles de l'administrateur.
- **`virt-host-validate`** fait un **check-up** : « cette machine peut-elle être un hyperviseur ? ». **`qemu`** = pour QEMU/KVM.

✅ **Ce que tu dois voir :**

| Test | Résultat | Signification |
|---|---|---|
| hardware virtualization | **ÉCHEC** | pas de VT-x (attendu, partie 4) → émulation |
| `/dev/vhost-net`, `/dev/net/tun` | PASS | le réseau virtuel des VM est prêt |
| cgroup cpu, cpuacct, cpuset, memory, devices, blkio | PASS | Linux sait **limiter** le CPU, la RAM et le disque de chaque VM |
| IOMMU | WARN | on ne peut pas donner une **vraie** carte (graphique, réseau) à une VM. Inutile ici. |
| secure guest (SEV, TDX) | WARN | pas de chiffrement de la mémoire des VM. Inutile ici. |

📖 **cgroups** : une fonction de Linux qui met des **limites** à un groupe de programmes (« cette VM n'a pas droit à plus de 256 Mo »).

📸 **Capture :** `13-virt-host-validate.png`

![virt-host-validate](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/13-virt-host-validate.png)

### 12.5 libvirt et le réseau `default`

⌨️ **Commandes :**

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
virsh -c qemu:///system net-info default
ip -4 -br addr show virbr0
```

🔍 **Explication :**
- **`virsh`** = la commande pour parler à libvirt.
- **`-c qemu:///system`** = « connecte-toi au libvirt **du système** » (celui qui gère les VM officielles de la machine). Il existe aussi `qemu:///session` (un libvirt par utilisateur), qu'on n'utilise pas.
- **`list --all`** = toutes les VM, même éteintes.
- **`net-list --all`** = les réseaux virtuels. **`net-info default`** = la fiche du réseau `default`.
- **`ip -4 -br addr show virbr0`** = l'adresse IPv4 du pont `virbr0`.

✅ **Ce que tu dois voir :**
- `list --all` → un tableau **vide** (pas encore de VM) ;
- `net-list` → **`default   actif   oui   oui`** (actif, démarrage automatique, permanent) ;
- `net-info` → **`Pont : virbr0`** ;
- `virbr0` → **`192.168.122.1/24`**.

📸 **Capture :** `14-virsh-reseau-default.png`

![virsh reseau default](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/14-virsh-reseau-default.png)

🆘 **Si ça ne marche pas :** la première fois, on a eu :

```
error: l'authentification n'est pas disponible : aucun agent polkit disponible pour s'authentifier action 'org.libvirt.unix.manage'
```

👉 Ça veut dire : **lami n'a pas le droit** de gérer les VM du système. 📖 **polkit** est le « vigile » de Linux qui décide qui a le droit de faire quoi. Solution : étape 8.

🧠 **À retenir (étape 7)**
- `dnf group list --installed` → **« Hôte de virtualisation »** = KVM installé pendant l'installation.
- `virtqemud` actif, réseau `default` actif sur `virbr0` = 192.168.122.1.
- Pas de `/dev/kvm`, `vmx` = 0, `virt-host-validate` en ÉCHEC = **pas de turbo** → émulation.

---

## 13. Étape 8 – Donner à lami le droit de gérer les VM

🎯 **Objectif :** que `lami` puisse utiliser `virsh -c qemu:///system`.

🤔 **Pourquoi :** sous Linux, les droits se donnent souvent par **groupes**. L'installation de libvirt a créé un groupe **`libvirt`** : ses membres ont le droit de gérer les VM.

📍 **Où :** 🐧 terminal Rocky (SSH).

⌨️ **Commandes :**

```bash
sudo usermod -aG libvirt lami
exit
```

Puis reconnecte-toi : dans 🪟 PowerShell, flèche ↑ puis Entrée.

🔍 **Explication :**
- **`usermod`** = modifier un utilisateur ;
- **`-a`** (*append*) = **ajouter** un groupe. ⚠️ Sans `-a`, lami serait **retiré** de tous ses autres groupes, y compris `wheel` : il perdrait `sudo` !
- **`-G libvirt`** = le groupe à ajouter ;
- **`exit`** puis reconnexion : un nouveau groupe compte seulement à la **prochaine connexion**.

✅ **Ce que tu dois voir :** `id` affiche `groupes=1000(lami),10(wheel),997(libvirt)`, et `virsh -c qemu:///system list --all` marche sans erreur.

💼 **Dans la vraie vie :** donner les droits par **groupe** (et pas en donnant le mot de passe root) est la bonne pratique. On sait **qui** a quels droits, et on peut les retirer facilement.

---

## 14. Étape 9 – Télécharger l'image CirrOS

🎯 **Objectif :** récupérer le disque de la VM de test.

🤔 **Pourquoi :** CirrOS est fourni **déjà installé**, sous forme d'un fichier disque. Il suffit de le télécharger.

📍 **Où :** 🐧 terminal Rocky (SSH).

⌨️ **Commandes :**

```bash
sudo curl -L -o /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
sudo qemu-img info /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img
sudo md5sum /var/lib/libvirt/images/cirros-0.6.3-x86_64-disk.img
curl -sL https://download.cirros-cloud.net/0.6.3/MD5SUMS | grep x86_64-disk.img
```

🔍 **Explication :**
- **`curl`** télécharge un fichier. **`-L`** = suivre les redirections ; **`-o ...`** = où l'enregistrer ; **`-s`** = silencieux.
- **`/var/lib/libvirt/images/`** = le **dossier officiel** des disques de VM. Il faut `sudo` pour y écrire. 📖 **SELinux** (la sécurité de Rocky) autorise libvirt à lire **ce** dossier. Ailleurs, la VM pourrait refuser de démarrer.
- **`qemu-img info`** décrit un fichier disque de VM.
- **`md5sum`** calcule une empreinte. La dernière commande lit l'empreinte officielle, pour comparer.

✅ **Ce que tu dois voir :**
- `file format: qcow2`, `virtual size: 112 MiB`, `disk size: 20.7 MiB` ;
- deux empreintes identiques : `87617e24a5e30cb3b87fda8c0764838f` ✅.

📖 **qcow2** (*QEMU Copy-On-Write v2*) est le **format de disque** de QEMU/KVM, l'équivalent du `.vmdk` de VMware. Le disque fait 112 Mo **vu de la VM**, mais le fichier n'en prend que 21 : il ne stocke que ce qui est vraiment écrit.

---

## 15. Étape 10 – Créer la VM avec virt-install

🎯 **Objectif :** créer et démarrer la VM `cirros-test` dans KVM.

🤔 **Pourquoi :** c'est le test final : notre hyperviseur doit faire tourner une VM.

📍 **Où :** 🐧 terminal Rocky (SSH).

⌨️ **a) Trouver le type de système à annoncer :**

```bash
osinfo-query os | grep -i cirros
```

🔍 **`osinfo-query os`** liste tous les systèmes connus de libvirt (Windows, Ubuntu, CirrOS…). **`grep -i cirros`** ne garde que CirrOS (`-i` = sans tenir compte des majuscules). La liste s'arrête à **`cirros0.5.2`** : notre 0.6.3 est trop récente pour y figurer, donc on prend **la plus proche**.

⌨️ **b) Créer la VM.** Le **`\`** en fin de ligne veut dire « la commande continue à la ligne suivante » :

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

🔍 **Explication, option par option :**

| Option | Signification |
|---|---|
| `--connect qemu:///system` | créer la VM dans le libvirt **du système** |
| `--name cirros-test` | le **nom** de la VM |
| `--import` | le disque contient **déjà** un système : pas d'installation, on démarre directement dessus |
| `--disk path=...` | le **disque** de la VM (le fichier téléchargé) |
| `format=qcow2` | le format de ce fichier |
| `bus=virtio` | 📖 **virtio** = des pilotes spéciaux, **rapides**, faits pour les VM (on dit « paravirtualisés ») |
| ⭐ `--virt-type qemu` | **émulation** (pas de turbo, partie 4). Avec VT-x, on mettrait `kvm`. |
| `--memory 256` | 256 Mo de RAM |
| `--vcpus 1` | 1 processeur virtuel |
| `--os-variant cirros0.5.2` | le type de système, pour que libvirt choisisse de bons réglages |
| `--network network=default` | brancher la VM sur le réseau `default` (le pont `virbr0`) |
| `--graphics none` | **pas d'écran graphique** : on utilisera une **console texte** (le port série) |
| `--noautoconsole` | ne pas ouvrir la console tout de suite : la commande rend la main |

✅ **Ce que tu dois voir :**

```
Début d'installation…
Création du domaine…
Création de domaine terminée.
```

📖 **Domaine** = le mot de libvirt pour dire « VM ».

> ℹ️ Le message `WARNING **: Entity http://pcisig.com/pci/1af4/1012 referenced but not defined` peut apparaître. Il vient de la base `osinfo`, qui cite un identifiant de matériel virtio sans le décrire. Il est **sans danger** : la dernière ligne confirme que la VM est créée.

📸 **Capture :** `15-cirros-virt-install.png`

![virt-install](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/15-cirros-virt-install.png)

---

## 16. Étape 11 – Vérifier que la VM tourne et a une IP

📍 **Où :** 🐧 terminal Rocky (SSH).

### 16.1 La VM est-elle allumée ?

⌨️ **Commandes :**

```bash
virsh -c qemu:///system list --all
virsh -c qemu:///system dominfo cirros-test
```

🔍 **`list --all`** = les VM et leur **état** ; **`dominfo`** = la **fiche d'identité** d'une VM (*domain info*).

✅ **Ce que tu dois voir :** `cirros-test   en cours d'exécution`. Dans `dominfo` : `CPU : 1`, `Mémoire Max : 262144 KiB` (= 256 Mo), et :

```
Étiquette de sécurité : system_u:system_r:svirt_tcg_t:s0:c751,c1001 (enforcing)
```

👉 Le mot **`tcg`** dans `svirt_tcg_t` **confirme l'émulation**. Avec le turbo KVM, ce serait `svirt_t`.

📖 **sVirt** : SELinux enferme chaque VM dans sa propre **bulle**. Les nombres `c751,c1001` sont propres à cette VM : même piratée, elle ne pourrait pas lire les disques des autres.

📸 **Capture :** `16-virsh-list-running.png`

![virsh list running](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/16-virsh-list-running.png)

### 16.2 Quelle IP ? Répond-elle ?

⌨️ **Commandes :**

```bash
virsh -c qemu:///system domifaddr cirros-test
virsh -c qemu:///system net-dhcp-leases default
ping -c 4 192.168.122.168
```

🔍 **Explication :**
- **`domifaddr`** = les adresses des cartes réseau de la VM (*domain interface address*) ;
- **`net-dhcp-leases default`** = les adresses **prêtées** (les « baux ») par le DHCP du réseau `default` ;
- **`ping`** envoie de petits messages « tu es là ? ». **`-c 4`** = en envoyer **4** puis s'arrêter (sous Linux, sans `-c`, `ping` continue jusqu'à **Ctrl+C**).

(Sur la capture, l'IP est trouvée automatiquement avec `$(...)`. 📖 `$( commande )` = « remplace ceci par le résultat de la commande ».)

✅ **Ce que tu dois voir :**
- `vnet1   52:54:00:57:93:ee   ipv4   192.168.122.168/24` (📖 **`vnet1`** = le câble virtuel de la VM branché sur `virbr0` ; **`52:54:00:...`** = son adresse **MAC**, l'identifiant unique de la carte réseau) ;
- `4 paquets transmis, 4 reçus, 0% packet loss` ✅.

> ℹ️ `net-dhcp-leases` montre aussi `192.168.122.105`. C'est le bail d'une **première** VM CirrOS, supprimée puis recréée pour refaire la capture 15. Un bail reste noté jusqu'à son expiration : ce n'est pas une erreur.

📸 **Capture :** `17-cirros-ip-ping.png`

![IP et ping](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/17-cirros-ip-ping.png)

🆘 **Si ça ne marche pas :** `domifaddr` est vide → CirrOS démarre encore. **En émulation, il lui faut 3 à 4 minutes**. Il cherche d'abord un serveur de configuration « cloud » qui n'existe pas ici, et affiche `failed 1/20: ... request failed`. Attends et recommence.

---

## 17. Étape 12 – Entrer dans la VM avec la console

🎯 **Objectif :** se « mettre devant l'écran » de CirrOS et tester son réseau **de l'intérieur**.

🤔 **Pourquoi :** CirrOS n'a pas d'écran graphique (`--graphics none`). On utilise sa **console série**, un écran **texte** relié à libvirt.

📍 **Où :** d'abord 🐧 terminal Rocky (SSH), puis 📦 console CirrOS.

⌨️ **Commandes :**

🐧 Dans Rocky :

```bash
virsh -c qemu:///system console cirros-test
```

Appuie sur **Entrée** : `cirros login:` apparaît.
- **Utilisateur :** `cirros`
- **Mot de passe :** CirrOS l'**écrit lui-même** à l'écran : *« login as 'cirros' user. default password: ... »*. C'est un mot de passe **public**, prévu pour les tests. Il est masqué sur la capture.

📦 Puis, dans CirrOS (l'invite devient `$`) :

```sh
grep PRETTY /etc/os-release
ip -4 addr show eth0
ip route
ping -c 2 192.168.122.1
ping -c 2 8.8.8.8
exit
```

🔍 **Explication :**
- **`grep PRETTY /etc/os-release`** → `CirrOS 0.6.3` : on est bien **dans** la VM.
- **`ip -4 addr show eth0`** → l'IP vue **de l'intérieur** : `192.168.122.168/24`.
- **`ip route`** → la **route par défaut** (la porte de sortie) : `default via 192.168.122.1`, c'est-à-dire `virbr0` sur Rocky.
- **`ping 192.168.122.1`** → la VM parle à sa **passerelle** (Rocky).
- **`ping 8.8.8.8`** → la VM parle à **Internet** (8.8.8.8 est un serveur de Google), à travers **deux NAT** (libvirt, puis VMware).
- **`exit`** → se déconnecter de CirrOS.
- **Quitter la console** et revenir à Rocky : **Ctrl + ]**. Sur un clavier suisse, essaie **Ctrl + Alt Gr + ]**, ou **Ctrl + 5**.

✅ **Ce que tu dois voir :** les deux `ping` répondent avec `0% packet loss` ✅.

📸 **Capture :** `18-cirros-console.png`

![Console CirrOS](https://raw.githubusercontent.com/L4ami/TP-kvm-rocky-linux/main/captures/18-cirros-console.png)

🎉 **Le TP est réussi :** KVM a été installé **pendant** l'installation de Rocky, il fait tourner une VM, et cette VM a du réseau jusqu'à Internet.

🆘 **Si ça ne marche pas :** une commande affiche une longue aide `BusyBox ... Usage:` → 📖 CirrOS utilise **BusyBox**, des versions **simplifiées** des commandes Linux. Certaines options n'existent pas (par exemple `ip -br`). Utilise la forme simple : `ip -4 addr show eth0`.

---

## 18. Étape 13 – Tout éteindre proprement

🎯 **Objectif :** arrêter les VM sans rien abîmer.

🤔 **Pourquoi :** couper une VM brutalement, c'est comme **débrancher** un PC : on peut abîmer ses fichiers.

📍 **Où :** 🐧 terminal Rocky (SSH).

⌨️ **Commandes :**

```bash
virsh -c qemu:///system shutdown cirros-test
virsh -c qemu:///system list --all
sudo poweroff
```

🔍 **Explication :**
- **`shutdown`** = demander à la VM de s'éteindre, comme un appui **court** sur le bouton d'alimentation. (À l'inverse, **`destroy`** la coupe **brutalement**, comme si on arrachait la prise. Malgré son nom, `destroy` **ne supprime rien**.)
- **`list --all`** = vérifier que l'état est **`fermé`**.
- **`poweroff`** = éteindre Rocky proprement. La connexion SSH se coupe.

✅ **Ce que tu dois voir :** `cirros-test   fermé`, puis la VM `kvm-rocky` s'éteint dans VMware.

**Pour rallumer plus tard :** démarre `kvm-rocky` dans VMware, reconnecte-toi en SSH, puis `virsh -c qemu:///system start cirros-test`.

---

## 19. Problèmes rencontrés et solutions

| # | Ce qu'on a vu | Pourquoi | Ce qu'on a fait |
|---|---|---|---|
| 1 | `bcdedit` : « type d'entrée non valide » ; `Get-BitLockerVolume` : « Accès refusé » | ces commandes demandent les droits **administrateur** | relancées dans un **Terminal (administrateur)** |
| 2 | `virt-host-validate` : « hardware virtualization : ÉCHEC », pas de `/dev/kvm`, `vmx` = 0 | Windows garde VT-x pour sa sécurité (partie 4) | choix assumé : **émulation** (`--virt-type qemu`), comme `virt_type = qemu` dans OpenStack |
| 3 | `virsh` : « aucun agent polkit disponible » | lami n'avait pas le droit de gérer les VM du système | `sudo usermod -aG libvirt lami`, puis reconnexion |
| 4 | `virtqemud` « inactive (dead) » | service activé par socket : il dort quand on ne l'utilise pas | normal ; il est `active (running)` dès qu'une VM tourne |
| 5 | `osinfo-query` ne connaît pas CirrOS 0.6.3 | la base `osinfo` est plus ancienne que l'image | prendre la plus proche : `cirros0.5.2` |
| 6 | CirrOS pas prête : `failed 1/20: ... request failed` | démarrage lent en émulation (il cherche un serveur de configuration « cloud ») | attendre 3 à 4 minutes |
| 7 | `WARNING ... pcisig.com/pci/1af4/1012` pendant `virt-install` | identifiant absent de la base `osinfo` | sans conséquence |
| 8 | `ip -br` affiche une aide BusyBox dans CirrOS | BusyBox ne connaît pas l'option `-br` | utiliser `ip -4 addr show eth0` |

Les petits problèmes liés **uniquement** à l'automatisation sont dans l'annexe (tout en bas du document).

---

## 20. Lien avec ESXi et OpenStack

| Notion | TP 1 : ESXi | TP 2 : OpenStack | **TP 3 : KVM** |
|---|---|---|---|
| Hyperviseur | ESXi (type 1) | KVM/QEMU, piloté par **Nova** | **KVM/QEMU**, piloté par **libvirt** |
| Outil de gestion | client web / vSphere | Horizon (web) et commande `openstack` | **`virsh`**, **`virt-install`** |
| Format de disque | `.vmdk` | qcow2 (dans **Glance**) | **qcow2** |
| Réseau virtuel | vSwitch, groupes de ports | **Neutron** | réseau libvirt **`default`** (`virbr0` + DHCP + NAT) |
| Stockage | datastore | Glance / Cinder | `/var/lib/libvirt/images` |
| VM de test | — | CirrOS | **CirrOS** |
| Sans VT-x | les VM 64 bits ne démarrent pas | `virt_type = qemu` | **`--virt-type qemu`** |
| Prix | licence payante (Broadcom) | gratuit | **gratuit** |

💡 **Le lien le plus important :** **OpenStack utilise KVM et libvirt en dessous.** Quand on crée une instance dans OpenStack, Nova demande à libvirt de faire… exactement ce qu'on a fait ici avec `virt-install`. Ce TP montre la couche qu'OpenStack automatise.

---

## 21. Aide-mémoire des commandes

| Je veux… | Commande (🐧 Rocky, sauf la 1ʳᵉ) |
|---|---|
| me connecter au serveur (🪟) | `ssh -i $env:USERPROFILE\.ssh\kvm_rocky_key lami@192.168.190.145` |
| voir les VM | `virsh -c qemu:///system list --all` |
| démarrer / éteindre une VM | `virsh -c qemu:///system start NOM` / `shutdown NOM` |
| couper une VM de force | `virsh -c qemu:///system destroy NOM` |
| entrer dans une VM | `virsh -c qemu:///system console NOM` (sortir : Ctrl + ]) |
| voir l'IP d'une VM | `virsh -c qemu:///system domifaddr NOM` |
| voir les réseaux virtuels | `virsh -c qemu:///system net-list --all` |
| supprimer une VM (garder son disque) | `virsh -c qemu:///system undefine NOM` |
| créer une VM | `virt-install ...` (étape 10) |
| bilan de santé | `sudo virt-host-validate qemu` |

> 💡 **Astuce :** pour ne plus taper `-c qemu:///system` : `echo 'export LIBVIRT_DEFAULT_URI=qemu:///system' >> ~/.bashrc`, puis reconnecte-toi.

---

## 22. Sécurité : ce qu'on ne publie jamais

| Élément | Où il est | Publié ? |
|---|---|---|
| hash du mot de passe de lami | `config/ks.cfg`, `config/oemdrv/` | ❌ bloqué par `.gitignore` |
| clé **privée** SSH | `C:\Users\Lami\.ssh\kvm_rocky_key` | ❌ jamais copiée dans le dépôt |
| ISO, disques `.vmdk` | `D:\VM\`, `D:\VMs\` | ❌ trop gros et inutiles |
| mot de passe par défaut de CirrOS | écran de connexion de CirrOS | ❌ masqué sur la capture |
| clé **publique** SSH | `ks-publiable.cfg`, capture 05 | ✅ sans danger : c'est le cadenas |

📖 **`.gitignore`** = la liste des fichiers que Git ne doit **jamais** envoyer sur GitHub. Avant chaque publication, l'outil **gitleaks** vérifie aussi qu'aucun secret ne traîne.

---

## 23. Glossaire

| Mot | Définition simple |
|---|---|
| **VM** | un faux ordinateur, fabriqué par un logiciel |
| **Hôte / invité** | l'hôte fait tourner les VM ; l'invité est le système dans la VM |
| **Hyperviseur** | le logiciel qui crée et fait tourner les VM |
| **Type 1 / type 2** | type 1 = directement sur le matériel ; type 2 = un logiciel dans Windows |
| **KVM** | le module du noyau Linux qui fait de Linux un hyperviseur |
| **QEMU** | le logiciel qui fabrique le faux matériel des VM |
| **TCG / émulation** | QEMU traduit chaque instruction : ça marche sans VT-x, mais c'est lent |
| **libvirt / virtqemud** | le service qui gère toutes les VM |
| **virsh** | la commande pour parler à libvirt |
| **virt-install** | la commande pour créer une VM |
| **Domaine** | le mot de libvirt pour dire « VM » |
| **VT-x / AMD-V** | le « turbo » de virtualisation du processeur |
| **Virtualisation imbriquée** | une VM dans une VM |
| **VBS** | la sécurité de Windows qui utilise l'hyperviseur de Windows (et garde VT-x) |
| **BitLocker** | le chiffrement du disque de Windows |
| **ISO** | l'image d'un CD ou d'un DVD, dans un seul fichier |
| **Hash / empreinte** | l'empreinte digitale d'un fichier ou d'un mot de passe, à sens unique |
| **RHEL / Rocky** | le Linux d'entreprise de Red Hat / son clone gratuit |
| **Anaconda** | l'installateur de RHEL et de Rocky |
| **Environnement** | un profil de logiciels choisi à l'installation (ex. « Hôte de virtualisation ») |
| **Kickstart (`ks.cfg`)** | le fichier de réponses pour installer automatiquement |
| **OEMDRV** | le nom de CD qu'Anaconda inspecte tout seul pour trouver `ks.cfg` |
| **GRUB** | le menu de démarrage de Linux |
| **UEFI** | la méthode moderne de démarrage d'un PC |
| **Paquet** | un logiciel prêt à installer (`rpm`, `dnf`) |
| **Service** | un programme qui tourne en arrière-plan (`systemctl`) |
| **sudo / wheel** | `sudo` = commande en administrateur ; le groupe `wheel` en donne le droit |
| **root** | le super-administrateur de Linux |
| **polkit** | le « vigile » de Linux qui autorise ou refuse une action |
| **SELinux / sVirt** | la sécurité de Rocky, qui enferme chaque VM dans sa bulle |
| **cgroups** | la fonction de Linux qui limite le CPU et la RAM d'un groupe de programmes |
| **SSH** | une connexion à distance chiffrée, en ligne de commande |
| **Clé publique / privée** | le cadenas (à donner) / la clé (à garder secrète) |
| **Adresse IP** | l'adresse d'une machine sur le réseau |
| **/24** | les 3 premiers nombres de l'adresse = le réseau |
| **Passerelle** | la porte de sortie d'un réseau |
| **DHCP / bail** | le service qui prête une IP automatiquement / la durée de ce prêt |
| **NAT** | le partage d'une adresse vers l'extérieur |
| **Adresse MAC** | l'identifiant unique d'une carte réseau |
| **virbr0** | le switch virtuel du réseau `default` de libvirt |
| **virtio** | des pilotes rapides faits pour les VM |
| **qcow2** | le format de disque de QEMU/KVM (l'équivalent du `.vmdk`) |
| **CirrOS** | un Linux minuscule fait pour tester les hyperviseurs |
| **BusyBox** | des versions simplifiées des commandes Linux |
| **Proxmox VE** | une plateforme de virtualisation gratuite, basée sur KVM |

---

## 24. Quiz : teste-toi !

**1. KVM est-il un hyperviseur de type 1 ou de type 2 ?**
<details><summary>Réponse</summary>
Type 1 : il fait partie du noyau Linux, qui devient lui-même l'hyperviseur.
</details>

**2. Quelle est la différence entre KVM et QEMU ?**
<details><summary>Réponse</summary>
KVM utilise le turbo du processeur (VT-x) pour faire tourner le processeur virtuel vite. QEMU fabrique le reste du faux matériel (disque, réseau…), et peut aussi émuler le processeur sans KVM.
</details>

**3. Quelle ligne du kickstart installe KVM ?**
<details><summary>Réponse</summary>
<code>@^virtualization-host-environment</code> : l'environnement « Hôte de virtualisation ».
</details>

**4. Comment Anaconda a-t-il trouvé le fichier ks.cfg sans qu'on tape rien ?**
<details><summary>Réponse</summary>
Il était sur un petit CD dont le nom de volume est <code>OEMDRV</code>. Anaconda inspecte automatiquement ce nom au démarrage.
</details>

**5. Quelles sont trois façons de voir que le « turbo » VT-x est absent ?**
<details><summary>Réponse</summary>
<code>/dev/kvm</code> n'existe pas ; <code>grep -cE 'vmx|svm' /proc/cpuinfo</code> donne 0 ; <code>virt-host-validate qemu</code> affiche ÉCHEC sur « hardware virtualization ». (Aussi : <code>lsmod | grep kvm</code> ne montre rien.)
</details>

**6. Pourquoi a-t-on utilisé `--virt-type qemu` ?**
<details><summary>Réponse</summary>
Parce que la VM Rocky n'a pas VT-x (Windows le garde pour sa sécurité VBS). QEMU fonctionne alors en émulation (TCG). Avec VT-x, on mettrait <code>--virt-type kvm</code>.
</details>

**7. À quoi sert `virsh -c qemu:///system list --all` ?**
<details><summary>Réponse</summary>
À lister toutes les VM (même éteintes) du libvirt système.
</details>

**8. Pourquoi lami a-t-il dû être ajouté au groupe `libvirt` ?**
<details><summary>Réponse</summary>
Sans ce groupe, polkit refuse à lami le droit de gérer les VM du système. Commande : <code>sudo usermod -aG libvirt lami</code>, puis reconnexion.
</details>

**9. Quelle est l'adresse de `virbr0`, et à quoi sert-il ?**
<details><summary>Réponse</summary>
<code>192.168.122.1</code>. C'est le switch virtuel du réseau <code>default</code> : passerelle des VM, avec DHCP et NAT vers l'extérieur.
</details>

**10. Cite deux produits professionnels qui utilisent KVM.**
<details><summary>Réponse</summary>
Au choix : Proxmox VE, OpenStack (Nova), Red Hat OpenShift Virtualization, Google Compute Engine, AWS Nitro (basé sur KVM).
</details>

📝 Pour l'oral, voir aussi la [fiche de révision](https://github.com/L4ami/TP-kvm-rocky-linux/blob/main/docs/fiche-questions-oral.md) (19 questions avec réponses).

---

## 25. Résumé de révision

### 🧠 Les 10 choses à savoir par cœur

1. Une **VM** est un faux ordinateur ; l'**hyperviseur** les fait tourner.
2. **KVM** = le module Linux (type 1) ; **QEMU** = le faux matériel ; **libvirt** = le gestionnaire ; **virsh** et **virt-install** = les commandes.
3. « Installer KVM pendant l'installation » = choisir **« Hôte de virtualisation »** (`@^virtualization-host-environment`).
4. Un **kickstart** installe automatiquement ; Anaconda le trouve sur un CD nommé **OEMDRV**.
5. **Rocky** = clone gratuit de **RHEL** ; on ne prend pas RHEL 5, en fin de vie.
6. **VT-x** = le turbo. Ici, Windows le garde (VBS), donc **émulation** : `--virt-type qemu`.
7. **`virt-host-validate`**, **`/dev/kvm`** et **`vmx`** permettent de diagnostiquer le turbo.
8. Le réseau **`default`** = pont **`virbr0`** (192.168.122.1) + DHCP + NAT.
9. **SSH** par clé : la clé publique est le cadenas, la clé privée ne se publie jamais.
10. KVM est **gratuit** et utilisé partout (Proxmox, OpenStack, Google, AWS Nitro) ; c'est une alternative à ESXi, devenu plus cher.

### Conclusion

Ce TP termine la semaine Virtualisation. Après ESXi (l'hyperviseur commercial) et OpenStack (le cloud au-dessus des hyperviseurs), on a installé **la brique qui fait tourner OpenStack** : KVM, avec libvirt. Même sans le turbo VT-x, toute la chaîne fonctionne : installation automatique, vérifications, création d'une VM, réseau jusqu'à Internet.

---

## Annexe – Comment ce rendu a été produit

Pour ce TP, Claude a fait les étapes **avec des scripts**, au lieu de cliquer. Le résultat est le même que la méthode manuelle décrite plus haut. Cette annexe permet de relire ces scripts.

| Fichier | Rôle |
|---|---|
| `config/ks-publiable.cfg` | le kickstart de l'étape 4B (hash masqué) |
| `config/make-oemdrv-iso.ps1` | crée l'ISO `OEMDRV` avec IMAPI2 (le graveur de Windows) |
| `config/kvm-rocky.vmx` | la fiche technique de la VM. Au lieu de l'assistant, ce fichier a été écrit directement, et le disque créé avec `vmware-vdiskmanager.exe -c -s 60GB -a lsilogic -t 0` (`-c` = créer, `-s` = taille, `-a` = type de contrôleur, `-t 0` = un seul fichier qui grossit). La VM a été démarrée avec `vmrun -T ws start ...vmx gui`. |
| `config/verif-kvm.sh` | lance d'un coup les commandes de vérification de l'étape 7 |
| `config/cirros-console.py`, `config/cirros-live.py` | « tapent » automatiquement le login et les commandes dans la console CirrOS, en masquant le mot de passe à l'écran |
| `config/capture-fenetre.ps1` | capture la fenêtre VMware (captures 07 et 08) |
| `config/terminal-capture.ps1` + `config/captures-cmd/` | ouvre une **vraie** fenêtre PowerShell, y lance les commandes d'une capture, puis capture la fenêtre (03 à 18). Pour aller plus vite, chaque capture ouvre **une seule** connexion SSH qui lance toutes ses commandes. La capture 03b a été prise par Lami. |
| `logs/` | les sorties texte brutes de toutes les commandes |

**Petits problèmes liés à l'automatisation :**

| Problème | Solution |
|---|---|
| `Invoke-WebRequest` renvoyait le fichier `CHECKSUM` en nombres (des octets) | décoder avec `[Text.Encoding]::UTF8.GetString(...)` |
| `vmrun captureScreen` demande un identifiant dans la VM | capturer la fenêtre VMware avec la fonction Windows `PrintWindow` |
| `bcdedit` et `BitLocker` impossibles à lire sans droits administrateur | vérification faite à la main par Lami (capture 03b) |
| pour refaire la capture 15, la VM CirrOS a été supprimée puis recréée | `virsh destroy` puis `virsh undefine` (le disque est gardé), puis `virt-install` |
