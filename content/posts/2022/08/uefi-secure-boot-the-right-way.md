---
title: "UEFI Secure Boot the Right Way"
date: 2022-08-01T17:18:34-04:00
publishDate: 2022-08-05T08:57:28-04:00
draft: false
categories:
- cobalt shield
tags:
- systemd
- secureboot
- fde
- luks
- tpm
---
Security around the Linux boot process is a bit of a touchy subject. In fact,
if you dig deep enough you'll find that there are many ways to boot a Linux
system in general. There's many different bootloaders, for example, each with
their own strengths and weaknesses. In addition, depending on the system's or
the user's requirements, the system may also require booting with an initramfs
or initrd. You can even boot a Linux kernel directly by taking advantage of
its `CONFIG_EFI_STUB` option. While looking into the basics of securing booting
on my own machines I found that the documentation for it can sometimes be a bit
all over the place, and even then there are many guides out there that were
sometimes confusing or didn't give the exact answers to the questions I still
had. All in all, I spent about 2 or 3 weeks really digging into it and only
afterwards did I finally come up with a solution that works well enough for me
and makes booting my various Linux machines reasonably secure.

This post is a long-awaited one. I originally wanted to publish this a few
months ago, but systemd 251 was released which added a new feature that I
wanted to cover in addition to everything else I had compiled in. For those who
have been patiently waiting for me to finally publish this (you know who you
are), thank you.

For the sake of brevity (even though I've already well-exceeded it), I will
avoid going too much into the technical details for some of the aspects and
components of the following material. I will also be skipping over some of the
alternatives and different methods of setup. The depth that I will be going into
is what I feel is relevant to gain a basic understanding of the things that you,
as a user, are setting up if you decide to do it. This is in no way intended to
be a "quick guide" or "setup for the lazy", but that may soon follow if the
demand is high enough.

# The Current Situation

The first problem with securing the Linux boot process is that the diversity
of the many Linux distributions and how they configure the base system also
brings fragmentation around booting. This could make setting it up for yourself
difficult. Worse, most Linux distributions that do not already have UEFI secure
boot just don't support it, and trying to set it up for yourself may result in
system instability after system upgrades. Someone who wants to proceed on such a
distribution anyway will need to ensure that they perform some extra steps after
system updates or else they may be locked out of their system on next boot or
not have a bootable system at all.

Most Linux distributions with existing UEFI secure boot support do so by using
the GNU GRUB bootloader with a UEFI shim loader. What happens during boot is
that the system EFI firmware will execute GRUB, which then executes the shim,
which in turn executes the Linux kernel. The shim, when executed, will register
itself with the system EFI firmware in such a way that when the system firmware
wants to verify a signature for a to be executed EFI executable, it can ask the
shim to do so in addition to the firmware's verification. The result is a sort
of parallel signature verification process that allows EFI executables to have
their signatures verified by both the system EFI firmware and the shim. The
primary advantage of this is that the distribution can sign their own kernels
using keys included in the shim and those signatures will be verified without
the system owner needing to load those keys into the system firmware.

There are two problems that I (personally) have with this implementation. First,
the shim itself is signed by the Microsoft third-party key[^1]. The
corresponding public key is included by default in almost all system EFI
firmwares with secure boot support, and Microsoft uses this key pair to sign
other objects. What this means is that if an attacker had another object signed
with the same key pair, they could boot it on a machine with the key loaded in
the system firmware's trusted keys database. My understanding is that this
process is supposed to be restricted to trusted hardware vendors, but it doesn't
seem difficult to maneuver Microsoft into signing something that could
potentially have bugs, vulnerabilities, or even backdoors of its own to
compromise other machines.

The second problem is that a vulnerability in the GRUB bootloader could
potentially allow an attacker to bypass secure boot verification and boot a
malicious Linux kernel anyway. GRUB is no stranger to major security bugs that
could compromise secure booting, but this is unfair as a simple count of bugs
isn't the best indicator of a project's security track record. What is
noteworthy though, is that vulnerabilities found in GRUB are generally fixed in
bulk. This is because every time a massively critical vulnerability is found,
the Linux distributions need to get their bootloaders signed by Microsoft again
which isn't a very timely process. Because of this, many small GRUB
vulnerabilities will go unfixed for *months* until GRUB does its yearly major
release. Just this past June, a major release of GRUB was announced which fixed
multiple known security issues that have been festering for over a year[^2]!

GRUB aside, another major hurdle of Linux boot security is the initrd or
initramfs if one is in use. At boot, the kernel will also unpack an initrd
into memory which contains tools and kernel modules needed to finish booting the
system. For instance, if the root filesystem resides on a filesystem like ZFS
which is not available as a built in filesystem driver, the kernel needs to load
this kernel module from the initrd at boot in order to mount it. Another case
where this is needed is if the machine is (and it should be!) using disk
encryption. The kernel alone does not know how to decrypt the disk, let alone
ask the user for a passphrase. The initrd will contain the scripts and tools
needed to get this going. The initrd is undoubtedly a security-sensitive
object. A compromised initrd can potentially contain malicious code that can
then infect the rest of the system once it is booted. Unfortunately, current
boot security mechanisms like the aforementioned EFI shim loader in combination
with GRUB do not in any way protect the initrd from being tampered with
because there is no signature verification done against the initrd.

At this point I think it goes without saying that for proper boot security you
really really need to have an encrypted disk. An unencrypted and unverified root
filesystem really just means that an attacker with physical access can just
modify system files in order to cause the system to load malicious code. I
didn't feel it necessary to mention it until now because I figured having an
encrypted disk is basically standard security practice by this point and it's
not really related specifically to UEFI secure boot. But anyway, back to secure
boot...

# The Solution

Ultimately what needs to be done is to somehow protect every sensitive component
needed during boot from tampering. The way forward to solve all of these
problems is to take advantage of systemd's boot stub. No, not `systemd-boot`.
The boot stub.

The systemd boot stub is a small EFI executable that does nothing by itself.
But, if you use `objcopy` to build a concatenated blob containing the boot stub,
a Linux kernel which has `CONFIG_EFI_STUB` enabled, the initrd, the kernel's
commandline, and a splash image, you get a single file containing all these
components that can be signed for UEFI secure boot and executed. This resulting
file is called a unified kernel image. It's important to note that the systemd
boot stub does not actually require systemd on the system to be used. One can
easily compile the boot stub separately from the rest of systemd and copy it
over to various systems to be used. It is not even necessary to use
`systemd-boot` as the bootloader, as the resulting file with all the bits
embedded inside can be used as a standalone EFI payload that can be booted
directly from the system EFI firmware.

What we can do is generate our own signing keys for UEFI secure boot and load
them into the system firmware's trusted signature database. Then, we can use the
systemd boot stub to create our own unified kernel image and sign them using our
generated keys. Finally, we install our unified kernel image to the `/boot`
partition and either add it as an EFI payload in the system firmware or install
`systemd-boot` boot it.

Let's take it one step at a time, starting with...

## Generating Secure Boot Signing Keys

Ideally you'd do this on a separate system that is disconnected from the network
and do all of the signing on the same machine as well. That way an attacker who
gains code or command execution on the main machine cannot simply copy the UEFI
secure boot signing keys because they would not exist on the machine. However,
if you are someone like me who tends to update their kernel or initrd fairly
frequently this can be impractical. This would mean needing to update the kernel
and initrd, then copying them to the machine for signing, sign them, then
copying them back. There is definitely some security gains here to do it this
way, but I couldn't be bothered personally. From here on I will assume you are
working on the same machine to do the key generation and signing, but if you
would like to go the extra mile, simply do these steps on your airgapped machine
and follow the procedure I described above every time you need to re-sign your
kernel and things.

First, there's a few packages we will need to install. These packages contain
the tools needed to later sign our kernel images. On Gentoo, we can install
these by running:
```console
# emerge -av efitools sbsigntools
```

Then, let's create a directory on our system where we will store our keys.
```console
# mkdir /etc/secureboot
# chmod 0700 /etc/secureboot
```
We also set the directory's permissions to `0700` so that only the `root` user
can view its contents.

Next, let's create the keys. There are several key pairs that need to be created
and loaded into the EFI firmware and they are all related.

First, we will enter the directory where we will store the keys and generate a
globally unique identifier (GUID) for the machine:
```console
# cd /etc/secureboot
# uuidgen --random >guid.txt
```

Then, we will create the platform key:
```console
# openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=Platform Key/" -out PK.crt
# openssl x509 -outform DER -in PK.crt -out PK.cer
# cert-to-efi-sig-list -g "$(<guid.txt)" PK.crt PK.esl
# sign-efi-sig-list -g "$(<guid.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth
# sign-efi-sig-list -g "$(<guid.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth
```
The argument given to the `/CN=` field denotes the canonical name that will be
filled into the generated certificate. You can put pretty much whatever you want
in this field like the hostname of the machine you are generating keys for, but
I like to keep things simple.

The platform key is stored in the UEFI `PK` variable and it controls access to
that variable as well as the `KEK` variable, which is where the key exchange key
will be stored.

The above commands will have also created a file named `rm_PK.auth`. This file
can be installed to the `PK` variable in order to remove the platform key in the
event that it is needed.

Next, we need to create the key exchange key.
```console
# openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=Key Exchange Key/" -out KEK.crt
# openssl x509 -outform DER -in KEK.crt -out KEK.cer
# cert-to-efi-sig-list -g "$(<guid.txt)" KEK.crt KEK.esl
# sign-efi-sig-list -g "$(<guid.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth
```
The key exchange key is used to update the signature database or to sign
binaries that will be trusted by the system firmware for execution.

Finally, we will create the signature database.
```console
# openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=Signature Database Key/" -out db.crt
# openssl x509 -outform DER -in db.crt -out db.cer
# cert-to-efi-sig-list -g "$(<guid.txt)" db.crt db.esl
# sign-efi-sig-list -g "$(<guid.txt)" -k KEK.key -c KEK.crt db db.esl db.auth
```
The signature database is stored in the system's `db` variable and is what is
used to validate signed EFI binaries and other payloads when secure boot is
enabled.

## Installing Keys and Signing Things

Now that our keys are created, we can start signing objects with them. The way
to do this is via the `sbsign` utility:
```console
# sbsign \
    --key /etc/secureboot/db.key \
    --cert /etc/secureboot/db.crt \
    --output /boot/EFI/systemd/systemd-bootx64.efi \
    /boot/EFI/systemd/systemd-bootx64.efi
```
The above command will sign the systemd-boot bootloader and overwrite the
original file. If you wish to preserve the original, unsigned file, simply point
the `--output` argument to a different location.

In order to actually take advantage of signature verification, though, we need
to install our keys into the EFI firmware. We can do this from the running
operating system using the `efi-updatevar` utility:
```console
# efi-updatevar -f /etc/secureboot/PK.auth PK
# efi-updatevar -f /etc/secureboot/KEK.auth KEK
# efi-updatevar -f /etc/secureboot/db.auth db
```
If this is not an option, or you'd like to do this manually, you can instead
copy the `*.auth` files to the `/boot` directory or some other device that we
can read from the system firmware (usually an external FAT partition). Then,
from within the EFI firmware settings we can manually load the keys. Finally, we
can enable secure boot from within the firmware.

{{< notice warning >}}
If you are using a bootloader such as `systemd-boot`, you will need to ensure to
sign the bootloader itself or your system won't boot!
{{< /notice >}}

Either way you do this, you should ensure that you protect the firmware
settings from modification. On most motherboards this is generally just an
administrator password and admittedly could be better, but unfortunately this is
what we are stuck with. The reason you should do this is that an attacker with
physical access could simply wipe the secure boot keys or simply turn secure
boot off in order to trick the system into booting into an insecure state.

## Putting It All Together

Before any of what we are about to do can work, your kernel must have
`CONFIG_EFI_STUB` enabled. This is needed to allow the system firmware (or
systemd's boot stub) to pass execution directly to the kernel.

To ensure that the initrd is protected from tampering as well as the kernel
image, we'll need to combine the initrd and kernel into a single object for
signing. As mentioned earlier, the systemd boot stub is a small EFI executable
that can be combined with a Linux kernel, an initrd, the kernel commandline, and
a splash image in order to generate a single file that can be signed for secure
boot. For this we use `objcopy` to combine the required components:
```console
# objcopy --add-section .osrel="/etc/os-release" \
    --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="/etc/kernel/cmdline" \
    --change-section-vma .cmdline=0x30000 \
    --add-section .splash="/etc/kernel/splash.bmp" \
    --change-section-vma .splash=0x40000 \
    --add-section .linux="/boot/vmlinuz-5.15.58-gentoo" \
    --change-section-vma .linux=0x2000000 \
    --add-section .initrd="/boot/initramfs-5.15.58-gentoo" \
    --change-section-vma .initrd=0x4000000 \
    "/usr/lib/systemd/boot/efi/linuxx64.efi.stub" \
    "/boot/EFI/Linux/linux-5.15.58-gentoo.efi"
```
There's a lot to unpack here in this command, but let's go through it piece by
piece:

We embed various components into the resulting file. These are:
- `/etc/os-release` - the OS release information file
- `/etc/kernel/cmdline` - a plain text file containing the kernel commandline
- `/etc/kernel/splash.bmp` - a splash image in BMP format
- `/boot/vmlinuz-5.15.58-gentoo` - the kernel image
- `/boot/initramfs-5.5.15-gentoo` - the initrd

It should be noted that on Gentoo, the `VERSION_ID` field in `/etc/os-release`
may not exist. This field is read by `systemd-boot` when populating the list of
valid bootable entries. This is not needed if you intend to boot the image
directly from firmware, but if you are using `systemd-boot` you will need this
field. I have mine set to `"2.8"`.

Each argument which adds a file is separated by an argument which sets the
offset for the file to be inserted. I suggest not to change these as I'm pretty
sure they may be hard-coded but don't quote me on that.

Finally, near the end of the command we see the path to the systemd boot stub
and the output path to the resulting file.

For convenience, what I have done on my systems is install the `systemd-boot`
`installkernel` script (`installkernel-systemd-boot` on Gentoo) along with a
kernel install script hook I wrote that automates this process whenever I
rebuild the kernel:
```bash
#!/usr/bin/env bash

set -Eeuo pipefail

COMMAND="${1}"
KERNEL_VERSION="${2}"
BOOT_DIR_ABS="${3}"
KERNEL_IMAGE="${4-}"

# If KERNEL_INSTALL_MACHINE_ID is defined but empty, BOOT_DIR_ABS is a fake directory.
# So, let's skip creating a unified kernel image.
if ! [[ ${KERNEL_INSTALL_MACHINE_ID-x} ]]; then
    exit 0
fi

if [[ -d "${BOOT_DIR_ABS}" ]]; then
    INITRD="initrd"
    TARGET="../../EFI/Linux/linux-${KERNEL_VERSION}.efi"
else
    BOOT_DIR_ABS="/boot"
    INITRD="initramfs-${KERNEL_VERSION}.img"
    TARGET="linux-${KERNEL_VERSION}.efi"
fi

die() {
    echo "${1}"
    exit 1
}

case "${COMMAND}" in
    add)
        [[ -f "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/secureboot/db.key && -f "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/secureboot/db.cer ]] || die "No valid keys found in /etc/secureboot!"
        [[ -f "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/kernel/cmdline ]] || die "Cannot proceed: No such file '/etc/kernel/cmdline'"
        [[ -f "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/os-release ]] || die "Cannot proceed: No such file '/etc/kernel/splash.bmp'"

        args=(
            --add-section .osrel="${KERNEL_INSTALL_BOOT_ROOT}/../etc/os-release"
            --change-section-vma .osrel=0x20000
            --add-section .cmdline="${KERNEL_INSTALL_BOOT_ROOT}/../etc/kernel/cmdline"
            --change-section-vma .cmdline=0x30000
            --add-section .splash="${KERNEL_INSTALL_BOOT_ROOT}/../etc/kernel/splash.bmp"
            --change-section-vma .splash=0x40000
            --add-section .linux="${BOOT_DIR_ABS}/linux"
            --change-section-vma .linux=0x2000000
        )

        if [[ -f "${BOOT_DIR_ABS}/${INITRD}" ]]; then
            echo "Using initrd ${INITRD}"
            args+=(
                --add-section .initrd="${BOOT_DIR_ABS}/${INITRD}"
                --change-section-vma .initrd=0x4000000
            )
        fi
        args+=(
            "${KERNEL_INSTALL_BOOT_ROOT}/../usr/lib/systemd/boot/efi/linuxx64.efi.stub"
            "${BOOT_DIR_ABS}/${TARGET}"
        )

        echo "Creating unified kernel image..."
        objcopy ${args[@]}

        echo "Signing the unified kernel image..."
        sbsign \
            --key "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/secureboot/db.key \
            --cert "${KERNEL_INSTALL_BOOT_ROOT}"/../etc/secureboot/db.crt \
            --output "${BOOT_DIR_ABS}/${TARGET}" \
            "${BOOT_DIR_ABS}/${TARGET}"

        echo "Removing old loader entry..."
        rm -vf "${BOOT_DIR_ABS}/../../loader/entries/${KERNEL_INSTALL_MACHINE_ID}-${KERNEL_VERSION}.conf"
        ;;
    remove)
        rm -f -- "${BOOT_DIR_ABS}/${TARGET}"
        ;;
esac
```
The above script, when installed with executable permissions to
`/etc/kernel/install.d/99-secureboot.install`, take care of combining all these
files together and installing them to the proper location.

## Going a Step Further

`systemd-cryptenroll` is a utility that enrolls new key slots into an existing
LUKS device. These new key slots can be handled by the `systemd-cryptsetup`
tool such that the user can be prompted to decrypt the device. The advantage
of these two tools in tandem is that we can enroll key slots that require the
user to do more than just enter a passphrase to unlock the device.
`systemd-cryptenroll` has support for PKCS#11-compliant security tokens, FIDO2
tokens, and TPM2 devices. The latter is what we will be focusing on here.

At a high level we can take advantage of a TPM2 device on the system to seal the
key to decrypt the root filesystem at boot, then have `systemd-cryptsetup` ask
us for a passphrase in order to ask the TPM to unseal the key. Why ask the TPM
to unseal the key? Well, this is because when we seal a key or some other secret
data in the TPM, the TPM will only unseal it if the platform configuration
registers (PCRs) match. What happens during boot is the TPM will have stored
hashes of each of the different components that were used during bootup, and if
we seal a secret in the TPM against these hashes, the TPM will only unseal the
secret if they match. What this means for us is that we can seal the disk
decryption key in the TPM against one or more TPM2 PCRs, and the system has to
be in a trusted state during boot in order for the disk to be decrypted. For me
this means that the TPM will only hand over the disk decryption key if secure
boot is enabled and all the signatures of the different payloads during boot
were successfully verified.

`systemd-cryptenroll` allows us to either add a key slot that requires a
passphrase or add a key slot that does not. The latter will allow the system to
boot without a passphrase so long the PCRs match. This is convenient in that we
can be sure that the system is in a secure state when it boots, but the risk is
that if the machine does something after booting is finished that could
potentially be compromised or used to leverage access, an attacker can do so.
A prime example of this is this lovely penetration test conducted by Dolos
Group[^3]. What they found was that even though the machine they were trying to
use for attack was properly configured for secure boot, the machine would
automatically connect to the company's internal network via an automatic VPN
connection that was established after boot. They were able to leverage this in
order to gain a foothold in the internal network even though the machine itself
was sufficiently secured. The solution? Require a PIN or passphrase to continue
booting even though the device was booted in a secure state. The takeaway is
that any potential attack surface that exists on the machine after boot cannot
be used if the attacker does not know the PIN or passphrase to complete the boot
process.

To ensure that `systemd-cryptenroll` can detect the TPM2 device, we can use:
```console
# systemd-cryptenroll --tpm2-device=list
PATH        DEVICE     DRIVER
/dev/tpmrm0 IFX0785:00 tpm_tis
```
This will print the path to the TPM device in `/dev` as well as information
about it if it is found. If you do not see a device here, make sure you actually
have a TPM2 device installed and that the kernel can load the appropriate driver
for it.

Since we have only one TPM2 device on this system, it is safe to use
`--tpm2-device=auto` when issuing commands that will work on the TPM. Otherwise,
we would need to specify the path to the TPM2 device in this argument. To enroll
a new key slot using TPM2 PCR 7, which is the PCR that stores the secure boot
state, we can use:
```console
# systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p2
```
This command will ask for the current passphrase to unlock the `/dev/nvme0n1p2`
LUKS partition and then enroll a new key slot against PCR 7 into it. At boot,
this partition will automatically be decrypted at boot as long as PCR 7 matches.
If, instead, we want to also enter a PIN or passphrase to unlock it in addition
to being in a secure boot state, we can use:
```console
# systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=true /dev/nvme0n1p2
```
This command is the same as the above except we add `--tpm2-with-pin=true` which
tells `systemd-cryptenroll` to enroll a key slot that requires both PCR 7 hashes
to match as well as for the user to enter a PIN or passphrase. When we enter
this command, it will again ask us to enter the current passphrase to unlock
`/dev/nvme0n1p2` and then ask for a PIN to use for unlocking via the TPM.
Although it says PIN for this prompt (and even when unlocking), non-numeric
characters are allowed.

We can also use other PCRs available in the TPM other than just PCR 7. The
`systemd-cryptenroll` man page[^4] has a table of well-known PCRs and their
contents. For example, PCR 0 will contain a measurement of the core system
firmware executable code. So, if you wanted to ensure that the system firmware
itself was not updated or modified since enrolling, you can include it:
```console
# systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0,7 --tpm2-with-pin=true /dev/nvme0n1p2
```
This gives an extra layer of defense in verifying that not only secure boot is
in a known good state, but also checking other components. Keep in mind that by
enabling the use of other PCRs, updating any of these components (even
legitimately) will stop the TPM from unsealing secrets sealed against these
PCRs. Windows's BitLocker for example only uses PCR 7[^5], specifically to avoid
boot issues when the system owner updates the system firmware.

At this point the next best thing to do would be to enroll a recovery key to the
partition using the `--recovery-key` argument to `systemd-cryptenroll` and then
securely storing it somewhere and wiping the original passphrase slot. This
would ensure that the LUKS partition can only be unlocked by using a
PIN/passphrase in conjunction with being in a secure boot state. The downside of
this is that if something were to ever go wrong with the boot process, you would
likely be locked out of the system until you have access to the recovery key.

[^1]: https://techcommunity.microsoft.com/t5/hardware-dev-center/updated-uefi-signing-requirements/ba-p/1062916
[^2]: https://www.openwall.com/lists/oss-security/2022/06/07/5
[^3]: https://dolosgroup.io/blog/2021/7/9/from-stolen-laptop-to-inside-the-company-network
[^4]: https://www.freedesktop.org/software/systemd/man/systemd-cryptenroll.html#--tpm2-pcrs=PCR
[^5]: https://docs.microsoft.com/en-us/windows/security/information-protection/bitlocker/bitlocker-group-policy-settings#about-the-platform-configuration-register-pcr
