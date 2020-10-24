---
title: "Nextcloud cron with SELinux"
date: 2020-10-24T13:10:00-04:00
draft: false
categories:
- uncategorized
tags:
- untagged
---
If you run your own Nextcloud instance, one of the things you will need to do when finalizing setup is to configure Nextcloud's [internal cron service](https://docs.nextcloud.com/server/20/admin_manual/configuration_server/background_jobs_configuration.html).
\
\
The default and least reliable option is AJAX, which will run the cron service each time a Nextcloud page is requested. The immediate problem here is that if your Nextcloud instance does not have much continuous usage (like mine), especially from a web browser, the cron service will not run as often as it needs to.
\
\
The recommended option is system cron, which requires setting up a system cronjob like so:
```sh
*/5 * * * * nginx php -f /var/www/nextcloud/htdocs/cron.php
```
This cronjob will call the `cron.php` service directly running under the `nginx` user. On typical systems this is fine, but if you are using SELinux then you will notice some problems like the following:
```sh
node=megumin type=AVC msg=audit(1603560001.338:3684): avc:  denied  { execmem } for  pid=30481 comm="php" scontext=system_u:system_r:system_cronjob_t:s0-s0:c0.c1023 tcontext=system_u:system_r:system_cronjob_t:s0-s0:c0.c1023 tclass=process permissive=1
node=megumin type=AVC msg=audit(1603560001.338:3684): avc:  denied  { execstack } for  pid=30481 comm="php" scontext=system_u:system_r:system_cronjob_t:s0-s0:c0.c1023 tcontext=system_u:system_r:system_cronjob_t:s0-s0:c0.c1023 tclass=process permissive=1
```
What's happening here is the cron service is running under the system cron context, which does not have permissions to execute writable memory, which is required for PHP to work.
\
\
These are two very sensitive and potentially dangerous permissions, so if you are like me, you may not want to simply grant these permissions to the system cron context. Instead, you think to try and create a stub script in order to set up a process transition like so:
```sh
#!/bin/sh
php -f /var/www/nextcloud/htdocs/cron.php
```
```sh
type phpfpm_cron_exec_t;
application_executable_file(phpfpm_cron_exec_t)
cron_system_entry(phpfpm_t, phpfpm_cron_exec_t)
```
Now we can label our script as `phpfpm_cron_exec_t`, make it executable, and tell our cronjob to execute this file.
\
\
But now we have new problems:
```sh
node=megumin type=AVC msg=audit(1603558690.194:3611): avc:  denied  { map } for  pid=27906 comm="sh" path="/bin/bash" dev="sda4" ino=13238332 scontext=system_u:system_r:phpfpm_t:s0 tcontext=system_u:object_r:shell_exec_t:s0 tclass=file permissive=1
node=megumin type=AVC msg=audit(1603558690.194:3611): avc:  denied  { execute_no_trans } for  pid=27906 comm="php-fpm" path="/bin/bash" dev="sda4" ino=13238332 scontext=system_u:system_r:phpfpm_t:s0 tcontext=system_u:object_r:shell_exec_t:s0 tclass=file permissive=1
node=megumin type=AVC msg=audit(1603558690.194:3611): avc:  denied  { read open } for  pid=27906 comm="php-fpm" path="/bin/bash" dev="sda4" ino=13238332 scontext=system_u:system_r:phpfpm_t:s0 tcontext=system_u:object_r:shell_exec_t:s0 tclass=file permissive=1
node=megumin type=AVC msg=audit(1603558690.194:3611): avc:  denied  { execute } for  pid=27906 comm="php-fpm" name="bash" dev="sda4" ino=13238332 scontext=system_u:system_r:phpfpm_t:s0 tcontext=system_u:object_r:shell_exec_t:s0 tclass=file permissive=1
```
The `phpfpm_t` type does not have the permissions needed to run a shell and execute the `php` binary.
\
\
So that takes us back to square one. Let's take another look at our options again. We also have the option of using a Webcron service. It took me a minute to figure this out since I had never heard of it before, but essentially you can use a third-party service which will send HTTP GET requests (or whatever you configure) to endpoints on your webserver, which will trigger PHP to do something on the backend. After realizing what this could do for us, I came up with the following solution.
\
\
We can use the Webcron service and simply `curl` our `cron.php` internally using the system cron. Easy!
\
\
So we create a cronjob like so:
```sh
*/5 * * * * root curl https://nextcloud.example.com/cron.php >/dev/null
```
And then we tell Nextcloud that we are using a Webcron. That's it!
\
\
Additionally, you could even restrict the cron service endpoint to the local host or network only. To do this, you can insert this block into your Nextcloud's server definition in Nginx:
```sh
location = /cron.php {
    allow 127.0.0.1/32;
    deny all;
}
```
Finally, we have Nextcloud's cron service set up, fully working, and playing nice with SELinux.
