# PHP Configuration Cheat Sheet

## Introduction

Secure configuration of PHP and its web server.

Covers `php.ini` settings and Apache, Nginx, Caddy configuration.

General PHP codebase security guides:

- Paragonie's 2018 PHP Security Guide
- Awesome PHP Security

## PHP Configuration and Deployment

### php.ini

Adapt some settings to system, esp. `session.save_path`, `session.cookie_path` (e.g. `/var/www/mysite`), `session.cookie_domain` (e.g. `ExampleSite.com`).

Run PHP branch listed on official Supported Versions page; plan upgrades before security-support end date. Distro vendor extended support ≠ upstream branch supported. Core `php.ini` directives in PHP Manual = complete reference for every value.

Ready-to-go `php.ini` copy of values below exists (very-secure-php-ini).

#### PHP error handling

```text
expose_php              = Off
error_reporting         = E_ALL
display_errors          = Off
display_startup_errors  = Off
log_errors              = On
error_log               = /valid_path/PHP-logs/php_error.log
ignore_repeated_errors  = Off
```

`display_errors` MUST be `Off` in production; check logs frequently.

#### PHP general settings

```text
doc_root                = /path/DocumentRoot/PHP-scripts/
open_basedir            = /path/DocumentRoot/PHP-scripts/
include_path            = /path/PHP-pear/
extension_dir           = /path/PHP-extensions/
mime_magic.magicfile    = /path/PHP-magic.mime
allow_url_fopen         = Off
allow_url_include       = Off
variables_order         = "GPCS"
allow_webdav_methods    = Off
session.gc_maxlifetime  = 600
```

`allow_url_*` stops LFIs escalating easily to RFIs.

#### PHP file upload handling

```text
file_uploads            = On
upload_tmp_dir          = /path/PHP-uploads/
upload_max_filesize     = 2M
max_file_uploads        = 2
```

App w/o file uploads (e.g. only forms, no attachments): set `file_uploads` `Off`.

#### PHP executable handling

```text
enable_dl               = Off
disable_functions       = system, exec, shell_exec, passthru, phpinfo, show_source, highlight_file, popen, proc_open, fopen_with_path, dbmopen, dbase_open, putenv, move_uploaded_file, chdir, mkdir, rmdir, chmod, rename, filepro, filepro_rowcount, filepro_retrieve, posix_mkfifo
disable_classes         =
```

Dangerous functions. Disable all unused.

#### PHP session handling

Session settings = MOST important values. Change `session.name` to new value.

```text
 session.save_path                = /path/PHP-session/
 session.name                     = myPHPSESSID
 session.auto_start               = Off
 session.use_trans_sid            = 0
 session.cookie_domain            = full.qualified.domain.name
 #session.cookie_path             = /application/path/
 session.use_strict_mode          = 1
 session.use_cookies              = 1
 session.use_only_cookies         = 1
 session.cookie_lifetime          = 14400 # 4 hours
 session.cookie_secure            = 1
 session.cookie_httponly          = 1
 session.cookie_samesite          = Strict
 session.cache_expire             = 30
 session.sid_length               = 256
 session.sid_bits_per_character   = 6
```

#### Some more security paranoid checks

```text
session.referer_check   = /application/path
memory_limit            = 50M
post_max_size           = 20M
max_execution_time      = 60
report_memleaks         = On
html_errors             = Off
zend.exception_ignore_args = On
```

### Snuffleupagus

Snuffleupagus: spiritual descendant of Suhosin for PHP 7+, modern features. Stable, production-usable.

## References

- PHP Manual: Core php.ini Directives
- Snuffleupagus: Security Features
