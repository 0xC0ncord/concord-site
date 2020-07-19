---
title: "Quick Word on Gitea Dump"
date: 2020-07-18T22:04:15-04:00
draft: false
categories:
- "help desk"
tags:
- gitea
- postgres
- git
- quick-fix
---

Only today did I notice that my Gitea instance was unable to create new repositories. A furious search turned up [this issue](https://github.com/go-gitea/gitea/issues/4407) regarding the issue. [This comment](https://github.com/go-gitea/gitea/issues/4407#issuecomment-469031232) explains it in more detail. The fix is to run this on the Gitea database:

```sql
SELECT SETVAL('public.access_id_seq', COALESCE(MAX(id), 1) ) FROM public.access;
SELECT SETVAL('public.access_token_id_seq', COALESCE(MAX(id), 1) ) FROM public.access_token;
SELECT SETVAL('public.action_id_seq', COALESCE(MAX(id), 1) ) FROM public.action;
SELECT SETVAL('public.attachment_id_seq', COALESCE(MAX(id), 1) ) FROM public.attachment;
SELECT SETVAL('public.collaboration_id_seq', COALESCE(MAX(id), 1) ) FROM public.collaboration;
SELECT SETVAL('public.comment_id_seq', COALESCE(MAX(id), 1) ) FROM public.comment;
SELECT SETVAL('public.commit_status_id_seq', COALESCE(MAX(id), 1) ) FROM public.commit_status;
SELECT SETVAL('public.deleted_branch_id_seq', COALESCE(MAX(id), 1) ) FROM public.deleted_branch;
SELECT SETVAL('public.deploy_key_id_seq', COALESCE(MAX(id), 1) ) FROM public.deploy_key;
SELECT SETVAL('public.email_address_id_seq', COALESCE(MAX(id), 1) ) FROM public.email_address;
SELECT SETVAL('public.follow_id_seq', COALESCE(MAX(id), 1) ) FROM public.follow;
SELECT SETVAL('public.gpg_key_id_seq', COALESCE(MAX(id), 1) ) FROM public.gpg_key;
SELECT SETVAL('public.hook_task_id_seq', COALESCE(MAX(id), 1) ) FROM public.hook_task;
SELECT SETVAL('public.issue_assignees_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue_assignees;
SELECT SETVAL('public.issue_dependency_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue_dependency;
SELECT SETVAL('public.issue_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue;
SELECT SETVAL('public.issue_label_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue_label;
SELECT SETVAL('public.issue_user_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue_user;
SELECT SETVAL('public.issue_watch_id_seq', COALESCE(MAX(id), 1) ) FROM public.issue_watch;
SELECT SETVAL('public.label_id_seq', COALESCE(MAX(id), 1) ) FROM public.label;
SELECT SETVAL('public.lfs_lock_id_seq', COALESCE(MAX(id), 1) ) FROM public.lfs_lock;
SELECT SETVAL('public.lfs_meta_object_id_seq', COALESCE(MAX(id), 1) ) FROM public.lfs_meta_object;
SELECT SETVAL('public.login_source_id_seq', COALESCE(MAX(id), 1) ) FROM public.login_source;
SELECT SETVAL('public.milestone_id_seq', COALESCE(MAX(id), 1) ) FROM public.milestone;
SELECT SETVAL('public.mirror_id_seq', COALESCE(MAX(id), 1) ) FROM public.mirror;
SELECT SETVAL('public.notice_id_seq', COALESCE(MAX(id), 1) ) FROM public.notice;
SELECT SETVAL('public.notification_id_seq', COALESCE(MAX(id), 1) ) FROM public.notification;
SELECT SETVAL('public.org_user_id_seq', COALESCE(MAX(id), 1) ) FROM public.org_user;
SELECT SETVAL('public.protected_branch_id_seq', COALESCE(MAX(id), 1) ) FROM public.protected_branch;
SELECT SETVAL('public.public_key_id_seq', COALESCE(MAX(id), 1) ) FROM public.public_key;
SELECT SETVAL('public.pull_request_id_seq', COALESCE(MAX(id), 1) ) FROM public.pull_request;
SELECT SETVAL('public.reaction_id_seq', COALESCE(MAX(id), 1) ) FROM public.reaction;
SELECT SETVAL('public.release_id_seq', COALESCE(MAX(id), 1) ) FROM public.release;
SELECT SETVAL('public.repo_indexer_status_id_seq', COALESCE(MAX(id), 1) ) FROM public.repo_indexer_status;
SELECT SETVAL('public.repo_redirect_id_seq', COALESCE(MAX(id), 1) ) FROM public.repo_redirect;
SELECT SETVAL('public.repo_unit_id_seq', COALESCE(MAX(id), 1) ) FROM public.repo_unit;
SELECT SETVAL('public.repository_id_seq', COALESCE(MAX(id), 1) ) FROM public.repository;
SELECT SETVAL('public.review_id_seq', COALESCE(MAX(id), 1) ) FROM public.review;
SELECT SETVAL('public.star_id_seq', COALESCE(MAX(id), 1) ) FROM public.star;
SELECT SETVAL('public.stopwatch_id_seq', COALESCE(MAX(id), 1) ) FROM public.stopwatch;
SELECT SETVAL('public.team_id_seq', COALESCE(MAX(id), 1) ) FROM public.team;
SELECT SETVAL('public.team_repo_id_seq', COALESCE(MAX(id), 1) ) FROM public.team_repo;
SELECT SETVAL('public.team_unit_id_seq', COALESCE(MAX(id), 1) ) FROM public.team_unit;
SELECT SETVAL('public.team_user_id_seq', COALESCE(MAX(id), 1) ) FROM public.team_user;
SELECT SETVAL('public.topic_id_seq', COALESCE(MAX(id), 1) ) FROM public.topic;
SELECT SETVAL('public.tracked_time_id_seq', COALESCE(MAX(id), 1) ) FROM public.tracked_time;
SELECT SETVAL('public.two_factor_id_seq', COALESCE(MAX(id), 1) ) FROM public.two_factor;
SELECT SETVAL('public.u2f_registration_id_seq', COALESCE(MAX(id), 1) ) FROM public.u2f_registration;
SELECT SETVAL('public.upload_id_seq', COALESCE(MAX(id), 1) ) FROM public.upload;
SELECT SETVAL('public.user_id_seq', COALESCE(MAX(id), 1) ) FROM public."user";
SELECT SETVAL('public.user_open_id_id_seq', COALESCE(MAX(id), 1) ) FROM public.user_open_id;
SELECT SETVAL('public.version_id_seq', COALESCE(MAX(id), 1) ) FROM public.version;
SELECT SETVAL('public.watch_id_seq', COALESCE(MAX(id), 1) ) FROM public.watch;
SELECT SETVAL('public.webhook_id_seq', COALESCE(MAX(id), 1) ) FROM public.webhook;
```
