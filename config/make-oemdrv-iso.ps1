# Cree une petite ISO dont le label de volume est OEMDRV et qui contient ks.cfg.
# Anaconda (l'installateur de Rocky) cherche automatiquement un volume OEMDRV
# et charge le fichier ks.cfg qu'il trouve a la racine.
param(
    [string]$Source = "D:\tp-kvm\config\oemdrv",
    [string]$Output = "D:\VMs\kvm-rocky\oemdrv.iso"
)

$fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fsi.FileSystemsToCreate = 3          # 1 = ISO9660 + 2 = Joliet
$fsi.VolumeName = "OEMDRV"
$fsi.Root.AddTree($Source, $false)    # $false = mettre le contenu du dossier a la racine
$result = $fsi.CreateResultImage()

# IMAPI2 renvoie un flux COM (IStream) : un petit bout de C# le recopie dans un fichier
if (-not ("IsoWriter" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices.ComTypes;
public static class IsoWriter {
    public static void Write(object stream, string path, int blockSize, int blocks) {
        IStream s = (IStream)stream;
        byte[] buf = new byte[blockSize];
        using (FileStream fs = File.Create(path)) {
            for (int i = 0; i < blocks; i++) {
                s.Read(buf, blockSize, IntPtr.Zero);
                fs.Write(buf, 0, blockSize);
            }
        }
    }
}
'@
}
[IsoWriter]::Write($result.ImageStream, $Output, $result.BlockSize, $result.TotalBlocks)
Get-Item $Output
