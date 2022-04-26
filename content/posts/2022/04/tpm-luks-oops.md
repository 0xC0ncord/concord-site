---
title: "How not carefully reading the docs cost me a heart attack and a change of pants"
date: 2022-04-26T13:29:52-04:00
draft: false
categories:
- cobalt shield
- help desk
tags:
- gentoo
- systemd
- fde
- luks
- tpm
---
A couple weeks ago I was coming into work and wanted to quickly finish up some
experimentation I was doing with regards to setting up automatic disk decryption
at boot using TPM 2.0 and LUKS. I have been using full disk encryption (FDE) for
a while now but I wanted to try out the different ways that `systemd-cryptsetup`
supports unlocking the disk. Of the various methods, it seems that using a TPM
2.0 device to unlock the disk, given the validity of the system firmware and
secure boot state, was most interesting. The most desireable approach is
actually to use TPM 2.0 along with a passphrase or PIN, but [this
functionality](https://github.com/systemd/systemd/pull/22563) is not yet
available as it will be released in systemd v251.

Anyways, I had previously added a slot to the TPM consisting of PCRs 0,2,4,7 and
found that the disk was not automatically unlocking. I could verify that I had
the slot added with:
```console
# systemd-cryptenroll /dev/nvme0n1p2
```
I wanted to remove the old slot and try again, so I issued this command:
```console
# systemd-cryptenroll /dev/nvme0n1p2 --wipe-slot=0,2,4,7
```
Then, I went to add a new slot but with different PCRs, so I did:
```console
# systemd-cryptenroll /dev/nvme0n1p2 --tpm2-device=auto --tpm2-pcrs=0,7
```
This command prompted me for a passphrase like usual, but for some reason it
wouldn't accept my passphrase. When I reissued a command to view the slots,
this is what I saw:
```console
# systemd-cryptenroll /dev/nvme0n1p2
SLOT TYPE
   1 tpm2
```
My passphrase was gone! 😱

At this point I was in a bit of a panic. I tried a few more times out of
insanity to try and add in the passphrase again so that I could work on my
encrypted disk, but to no avail. I started to collect myself and had a couple
realizations. First, I couldn't think of any way to restore the passphrase into
the LUKS header of the disk without just reformatting it, and second, my disk
_was_ still decrypted at this point in time.

So, while continuously being paranoid of a kernel panic or largely improbable
cosmic event knocking out my laptop and costing all my data, I continued to work
until lunch came around, at which point I went back to the house and grabbed my
SATA to USB hard drive adapter and a spare 8TB hard disk drive I had laying
around. (Okay, the drive was meant to go into my desktop as a replacement but I
have been too lazy to do it as of late.)

I brought the two devices back to the office and continued to work until the
closing of the day. I immediately hooked up the drive to my laptop and began
copying over all my data with an `rsync` command. I left my laptop at the office
that day (locked to the desk, mind you) while the backup operation ran
overnight.

The next morning I came in to see that it had thankfully finished. With my
fingers crossed, I rebooted the laptop back into a Gentoo LiveDVD environment
and reformatted the LUKS partition with my old passphrase. Then, I began
recreating my LVM volumes on top of it and adjusting my `/etc/fstab`
accordingly. After the volumes were all mounted, I ran another `rsync` to begin
the restoration process and found something else to do at work while this was
running. Needless to say this also took basically the entire day, and I left my
laptop at the office for a second night while this completed.

At the dawn of the final day, I returned to my laptop to see it had finished.
After verifying that my `/etc/fstab` was correct and making the same adjustments
to the kernel commandline, I rebooted the machine and was greeted with a
pleasant TTY asking for my credentials. 👏

The last thing I needed to do after rebooting was fix the SELinux contexts on
the machine with a simple `rlpkg -ar` and manually fix the contexts on the
various mountpoints for the root inode of the volumes (sit tight for a minor
writeup on this as well).

After all was done it was like I had never screwed up in the first place. What I
didn't mention was that I was also researching on the side what exactly I did
wrong while the recovery was taking place. You may have already guessed it, but
my error was in thinking that the `--wipe-slot` argument took PCRs to wipe and
not the slot itself. Normally when you encrypt a disk with LUKS and a
passphrase, the passphrase goes into slot 0. When issuing the above wipe
command, I ended up removing the passphrase slot entirely. If the TPM unlocking
had worked, I could in theory have not worried so much about it, however I would
not be able to update the kernel or initramfs without breaking the disk
decryption process. Additionally, I never got it to work in the first place with
those PCRs.

I am writing this from the same laptop a couple weeks since this happened with a
fully working disk decryption with TPM 2.0 setup. It turns out that in addition
to the errors I made above, dracut currently has [a
bug](https://github.com/dracutdevs/dracut/pull/1677) that omits some of the
required libraries for systemd-cryptsetup to do its job. I had to manually
include these in my dracut config for the time being until a new version with
the fix is released. Lastly, I opted to stick with PCRs 0,7 for the time being
as this allows me to update my kernel and initramfs together without needing to
add a new slot for them every time.

Going forward, I intend to add a recovery key to the disk in the event that
something like this happens again. That way, I should still be able to
manipulate the LUKS header in case I do something similarly silly in my
experimentation.

Hopefully this was an interesting read and a lesson to carefully read the
corresponding documentation when working on particularly sensitive projects.

'til next time, see ya! 👋
