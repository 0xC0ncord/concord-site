---
title: >
    "Jammy Jellyfish" jammed my girlfriend's laptop
date: 2022-04-28T10:20:40-04:00
publishDate: 2022-05-03T05:03:40-04:00
draft: false
categories:
- help desk
tags:
- gentoo
- ubuntu
---
My girlfriend has been using Kubuntu 20.04 on her laptop almost since it was
released. Her intent was to become more familiar with Linux and computing in
general, which I am more than happy to help with. She was very enthusiastic from
the beginning about delving into the innards of a Linux desktop, but I didn't
want to overwhelm her with something as technical as Gentoo just yet. So,
because of some friendly recommendations and from my own personal experience I
settled on helping her get set up with Kubuntu 20.04 Focal Fossa.

It has been almost two years since we initially got her going. She spent a lot
of time customizing her KDE desktop just the way she liked, with a set of gaudy
icons, wallpapers, and animations that honestly were a bit out of my style. But,
nonetheless, she was happy with it and so was I. For the purposes of this post I
will forego mentioning how often I needed to remind her to update her system and
get to the point.

About a week ago I reminded her to run the regular update mechanism via `apt` on
her machine, only this time I suggested we upgrade the machine to Kubuntu 22.04
which was just freshly released. I had only heard of some minor complaints
regarding the release, mostly around the "forced" packaging of Firefox as a
snap and so I decided it was a good idea for her to do the upgrade, especially
since I was physically present. After running the appropriate `apt` commands to
update the local repo metadata and upgrade the installed packages, we performed
the `dist-upgrade` command and let it run. After about 20 minutes of churning
and answering some questions during the upgrade, the machine was ready to
reboot. And reboot it did.

Immediately we were presented with a problem: her laptop was hanging at the boot
process. Not long after exiting the initramfs, several `systemd` services would
fail to start including some critical ones like `systemd-logind`. To cut a long
story short I spent the next hour or so troubleshooting the machine with a
LiveUSB I was carrying around but without success. It was getting late at this
point and so I went to bed with the intent of continuing in the morning.

When I woke up, I got right to work with seeing if I could recover the machine.
I tried to see what (if any) problematic service was hanging boot, disabling
potentially unneeded services, and rebuilding the initramfs and Grub config, all
without success. I wasn't able to spend more than maybe an hour in the morning
before leaving for work unfortunately. When I got home I went right back to
trying to fix the machine before we decided it was best to just do a clean
reinstall. For some reason, however, the installer in Kubuntu would hang too! I
was able to navigate through some of the menus up until I was supposed to select
the disk partitioning scheme, but the menu would never finish loading. I tried
this several times before just giving up.

In the end I decided to just install Gentoo on the laptop. Unfortunately for my
girlfriend, she will need to deal with potentially long compile times and a much
steeper learning curve than we were hoping. Lucky for me though, installing
Gentoo on the machine makes me feel much more comfortable helping her with
technical issues and generally just feeling at home on her machine as if it were
my own. Plus, this alleviates the need to install it later if she ever decides
to take the next step in learning what I feel is a true Linux system.

I don't have any hard feelings towards Kubuntu or Ubuntu at this point, but I
have to admit that this whole ordeal did leave me and my girlfriend quite a bit
frustrated. I do get the feeling that we did something wrong during the upgrade,
but unfortunately we are beyond the point of finding out what really happened
that led to her laptop being in a broken state. Besides, in the long run I think
that shooting for the moon and installing Gentoo on the machine means my
girlfriend will be able to get a lot closer to the machine and learn the innards
a lot sooner than anticipated. Perhaps I'm getting ahead of myself though, since
she will need to get in the habit of doing routine updates first. 😜

'til next time. See ya!
