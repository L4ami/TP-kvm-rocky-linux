# Fiche de révision – Questions possibles du formateur (TP KVM)

Réponses courtes, à dire avec ses propres mots.

---

**1. C'est quoi KVM ?**
Un module du noyau Linux qui transforme Linux en hyperviseur de type 1. Il utilise les instructions de virtualisation du processeur (Intel VT-x ou AMD-V) pour faire tourner des VM rapidement.

**2. Quelle est la différence entre KVM et QEMU ?**
KVM fait tourner le processeur virtuel avec l'aide du vrai processeur. QEMU fabrique tout le reste du « faux matériel » (disque, carte réseau, écran…). On les utilise ensemble : QEMU avec l'accélération KVM.

**3. À quoi sert libvirt ?**
C'est une couche de gestion commune. Elle permet de créer, démarrer, arrêter et lister les VM et les réseaux virtuels avec les mêmes commandes, quel que soit l'hyperviseur. Sur Rocky 9, ce sont les services `virtqemud` (VM) et `virtnetworkd` (réseaux).

**4. Quelle est la différence entre `virsh` et `virt-install` ?**
`virsh` gère les VM qui existent déjà (lister, démarrer, arrêter, console, réseau…). `virt-install` sert à **créer** une nouvelle VM.

**5. Comment as-tu installé KVM « pendant l'installation » ?**
Dans le kickstart, j'ai choisi l'environnement logiciel « Virtualization Host » avec la ligne `@^virtualization-host-environment`. Anaconda a donc installé `qemu-kvm`, `libvirt` et leurs outils en même temps que le système.

**6. C'est quoi un kickstart ? Comment Anaconda l'a-t-il trouvé ?**
Un fichier (`ks.cfg`) qui contient toutes les réponses de l'installation : langue, clavier, disque, utilisateur, paquets. Je l'ai mis dans une petite ISO dont le nom de volume est `OEMDRV`. Anaconda cherche automatiquement ce nom et charge le `ks.cfg`.

**7. Comment vérifier que le processeur supporte la virtualisation ?**
`grep -cE 'vmx|svm' /proc/cpuinfo` (plus de 0 = oui), le fichier `/dev/kvm` doit exister, et `lsmod | grep kvm` doit montrer `kvm_intel` ou `kvm_amd`. On peut aussi lancer `virt-host-validate qemu`.

**8. Pourquoi `virt-host-validate` affiche « ÉCHEC » pour la virtualisation matérielle ?**
Parce que Rocky tourne dans une VM VMware sans VT-x imbriqué. Windows garde VT-x pour sa propre sécurité (VBS / Intégrité de la mémoire), qu'on a choisi de ne pas désactiver. Donc `/dev/kvm` n'existe pas.

**9. Alors comment ta VM CirrOS a-t-elle pu démarrer ?**
Avec `--virt-type qemu` : QEMU **émule** le processeur (mode TCG), il traduit chaque instruction. Ça marche, mais c'est beaucoup plus lent (environ 4 minutes de démarrage au lieu de quelques secondes). La preuve : l'étiquette SELinux `svirt_tcg_t` dans `virsh dominfo`.

**10. C'est quoi la virtualisation imbriquée ?**
Faire tourner une VM à l'intérieur d'une autre VM. Ici : Windows → VMware → Rocky (KVM) → CirrOS. Pour qu'elle soit rapide, l'hyperviseur du dessous doit transmettre VT-x à la VM (option « Virtualiser Intel VT-x/EPT » dans VMware).

**11. Comment fonctionne le réseau de ta VM CirrOS ?**
Elle est branchée sur le réseau libvirt `default` : un switch virtuel (`virbr0`, 192.168.122.1) avec un DHCP et du NAT. CirrOS a reçu 192.168.122.105. Pour sortir sur Internet, il y a deux NAT : celui de libvirt, puis celui de VMware.

**12. Pourquoi l'utilisateur `lami` n'arrivait pas à lancer `virsh -c qemu:///system` ?**
Il faut des droits pour gérer les VM du système. Polkit refusait. Solution : ajouter `lami` au groupe `libvirt` (`sudo usermod -aG libvirt lami`), puis se reconnecter.

**13. C'est quoi qcow2 ?**
Le format de disque de QEMU/KVM (*QEMU Copy-On-Write*). Le fichier ne prend que la place réellement utilisée et il gère les snapshots. C'est l'équivalent du VMDK de VMware.

**14. Quel est le lien avec ESXi et OpenStack ?**
Ce sont les mêmes notions (hyperviseur, VM, réseau virtuel, stockage), avec des outils différents. ESXi est l'hyperviseur de VMware, avec le format VMDK et des vSwitch. OpenStack utilise justement **KVM + libvirt** en dessous : Nova appelle libvirt pour créer les VM. Dans le TP OpenStack aussi, on était en `virt_type = qemu`.

**15. Pourquoi une clé SSH plutôt qu'un mot de passe ?**
La clé privée ne quitte jamais mon PC et ne peut pas être devinée comme un mot de passe. Le serveur ne garde que la clé publique (comme un cadenas). Et on peut se connecter sans taper de mot de passe.
