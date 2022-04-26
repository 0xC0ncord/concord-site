---
title: "Wrong run_init Authentication"
date: 2020-09-22T15:11:42-04:00
draft: false
categories:
- cobalt shield
- help desk
tags:
- gentoo
- selinux
- audit
- pam
---
Today I noticed that for some reason on one of my Gentoo boxes, I needed to authenticate as root in order to start and stop services, when on my other boxes I would authenticate as my currently logged in user. Normally I like to run `sudo -i` or `sudo -s` in order to run multiple tasks in the same session, and this was never previously a problem until I recently locked down the root account such that I could no longer enter its password (it no longer had one).

On Gentoo at least, when you need to execute some action on some service, the usage of `run_init` is required. The purpose of this utility is to change SELinux contexts from a user context to a system context for the purpose of running some action on some service. The reason for this is that doing this requires a change to the SELinux system user, role, and type, a highly privileged action. You can read more about this [here](https://wiki.gentoo.org/wiki/SELinux/Tutorials/Linux_services_and_the_system_u_SELinux_user). With this in mind, I started digging through my SELinux configuration, looking for anything out of the ordinary. Everything was in place. My SELinux login mapping was correct and I had access to all the correct roles. Then, I started looking through PAM. `run_init` is configured to authenticate through PAM using the configuration in `/etc/pam.d/run_init` which had no differences between both of my systems. Also checking `/etc/pam.d/system-auth` turned up no differences.

At this point I was beginning to pull my hair out a little, and went down the path of running `strace` against `run_init` to see what exactly was going on. I noticed that on the system where `run_init` was working as I was expecting, by asking me for my credentials instead of root's, `run_init` was reading the contents of `/proc/self/loginuid`, and the other system was not. Immediately after this file was read, PAM was invoked using the UID present in this file. That's when I had a vague realization of what was happening.

I did a quick search for what package was providing the `run_init` binary and thought to check its USE flags.
```shell
# equery b `which run_init`
 * Searching for /usr/sbin/run_init ...
sys-apps/policycoreutils-3.1 (/usr/sbin/run_init)

# equery u policycoreutils
[ Legend : U - final flag setting for installation]
[        : I - package is installed with flag     ]
[ Colors : set, unset                             ]
 * Found these USE flags for sys-apps/policycoreutils-3.1:
 U I
 - - audit                    : Enable support for sys-process/audit and use the audit_* functions (like audit_getuid instead of
                                getuid())
 - - dbus                     : Enable dbus support for anything that needs it (gpsd, gnomemeeting, etc)
 + + pam                      : Add support for PAM (Pluggable Authentication Modules) - DANGEROUS to arbitrarily flip
 - - python_targets_python3_6 : Build with Python 3.6
 + + python_targets_python3_7 : Build with Python 3.7

```
Ah ha! Sure enough, on the system where my user was being authenticated, the `audit` USE flag was set, and here it wasn't. A quick flip of this flag and a rebuild of `policycoreutils` fixed the problem.

This was a little bit of an oddity at first. I feel like this functionality should be separated from the `audit` USE flag in some way, as it looks like `run_init` checks what user is invoking some action in order to log it, but this information is also passed along to PAM. Without this check, `run_init` seems to assume that the root user is the one performing the action and does not authenticate the actual user against PAM. In any case, this simple change implemented the exact behavior I was looking for.
