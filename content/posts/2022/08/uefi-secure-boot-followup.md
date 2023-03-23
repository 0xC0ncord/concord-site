---
title: "A Small Follow-up to UEFI Secure Boot"
date: 2022-08-08T20:11:51-04:00
publishDate: 2023-03-23T11:44:58-04:00
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
This is a follow-up post to
[UEFI Secure Boot the Right Way]({{< ref "/content/posts/2022/08/uefi-secure-boot-the-right-way.md" >}})
in which I answer some questions I have received and to address some confusion
and clarify some erroneous information. Not only that, but I will share some
additional information that I found out about after publication of that post! 😃

## PCR 7 and Microsoft's Third-Party/Vendor CA Certificate

In my original post I expressed concern that including Microsoft's third-party
CA could potentially downgrade security of the boot process. It turns out that
this is partially due to a misunderstanding on how PCR 7 is populated and what
actually happens when you bind some value to PCRs in the TPM.

As the system boots, the hashes of all executed code is measured into PCR 7.
That is, hashes of each payload are subsequently "appended" to it. The result is
that if at any point one of these payloads differs from a previous boot, (as a
result of a bootloader update, for example), then PCR 7 will differ between
those boots. When you bind a LUKS key to PCR 7, it is guaranteed that the TPM
will only reveal the key if the boot process is the same as it was when it was
sealed in the first place.

So even if you leave Microsoft's third-party CA certificate in the trusted
store, changing what gets executed during boot will change the value of PCR 7
and the TPM will refuse to reveal the key that was sealed. In  short, my
original concerns about this are more or less moot.

## Microsoft's Third-Party/Vendor CA Certificate May Be Required on Some Hardware

This is an important piece of information I inadvertently left out. During the
hardware initialization process of booting, some devices will have option ROMs
with their own code that may need to be executed in order to initialize those
devices. The best example I can think of is NVIDIA graphics cards. More often
than not, if you install an NVIDIA GPU into your system and enable secure boot,
but neglect to install the Microsoft third-party/vendor CA certificate into the
trusted store, then the system will halt when booting because the option ROM is
not trusted by the firmware.

I actually ran into this exact problem a few years ago with exactly the same
setup. I ended up needing to remove the GPU, disabling secure boot, then
reinstalling it and ensuring to install Microsoft's third-party CA certificate
before enabling it again.

... Okay, I lied. I ended up RMAing the motherboard thinking I bricked it
somehow, and the vendor sent it back, unable to reproduce the problem. Only
after did I receive it did I follow the above procedure to fix the issue...

## Can malware touch secure boot properties while the OS is running?

Sort of. When UEFI passes execution to the running OS, it does so by calling
the `ExitBootServices()`[^1] function. Part of this process involves making
most EFI variables and functions read-only or inaccessible, including protected
properties governing the operation of secure boot.[^2] Additionally, a
UEFI-compliant system's PK (platform key) variable is made read-only as soon as
one is set. There are some other caveats around this which are far too technical
to describe here (and frankly, it's a little too much reading even for me), but
the gist is that as long as the system firmware has implemented this process
correctly, there isn't a concern. The secure boot variables that remain writable
within the running OS have to be authenticated, meaning that the values you put
in have to also be signed and trusted by the platform key. The only secure boot
variables with this property are the authorized device signature databases. This
is what allows things like Windows updates to add or remove trusted signatures
from the device as needed.

So basically, as long as you trust (and/or verify!) that your motherboard is
properly UEFI-compliant, then you're fine.

## `sbctl`, the Secure Boot Key Manager

Not long after the original post, I was informed about
[`sbctl`](https://github.com/Foxboron/sbctl) which does most of the legwork of
the script that I had written previously. I highly recommend using it, as it
more or less completely automates the process of generating secure boot keys,
enrolling keys, and signing arbitrary EFI executables with them. It will also
take care of installing the Microsoft third-party CA certificate if needed!

[^1]: https://uefi.org/specs/UEFI/2.10/07_Services_Boot_Services.html
[^2]: https://uefi.org/specs/UEFI/2.10/32_Secure_Boot_and_Driver_Signing.html
