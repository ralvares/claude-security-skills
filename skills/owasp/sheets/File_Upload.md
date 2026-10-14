# File Upload Cheat Sheet

## Introduction

File upload increasingly essential: users upload photo, CV, project video. App must fend off bogus/malicious files to keep app and users safe.

Principles for secure file upload:

- **List allowed extensions. Only allow safe and critical extensions for business functionality**
    - **Ensure [input validation](Input_Validation.md#file-upload-validation) applied before validating extensions.**
- **Validate file type; don't trust Content-Type header, can be spoofed**
- **Change filename to app-generated one**
- **Set filename length limit. Restrict allowed characters if possible**
- **Set file size limit**
- **Only allow authorized users to upload files**
- **Store files on different server. If not possible, store outside webroot**
    - **Public access to files: use handler mapped to filenames inside app (someid -> file.ext)**
- **Run file through antivirus or sandbox if available to validate no malicious data**
- **Run file through CDR (Content Disarm & Reconstruct) if applicable type (PDF, DOCX, etc...)**
- **Ensure any libraries used securely configured and kept up to date**
- **Protect file upload from [CSRF](Cross-Site_Request_Forgery_Prevention.md) attacks**

## File Upload Threats

Know the threats to choose controls.

### Malicious Files

Attacker delivers file w/ malicious intent, e.g.:

1. Exploit vulnerabilities in file parser/processing module (_e.g._ ImageTrick Exploit, XXE)
2. Use file for phishing (_e.g._ careers form)
3. Send ZIP bombs, XML bombs (billion laughs attack), or huge files to fill server storage → hurts availability
4. Overwrite existing file on system
5. Client-side active content (XSS, CSRF, etc.) endangering other users if files publicly retrievable.

### Public File Retrieval

Publicly retrievable uploads add threats:

1. Public disclosure of other files
2. DoS by requesting lots of files. Requests small, responses much larger
3. File content deemed illegal, offensive, dangerous (_e.g._ personal data, copyrighted data, etc.) → you host such malicious files.

## File Upload Protection

No silver bullet. Defense in depth key: multiple techniques recommended; no single technique enough.

### Extension Validation

Validate after decoding filename; use proper filter to avoid known bypasses, such as:

- Double extensions, _e.g._ `.jpg.php`, easily circumvents regex `\.jpg`
- Null bytes, _e.g._ `.php%00.jpg`: `.jpg` truncated, `.php` becomes new extension
- Case manipulation, _e.g._ `.pHp`, `.phP`, bypasses case-sensitive blocklist filters
- Alternative extensions mapped to same server-side interpreter depending on config, _e.g._ `.phtml`, `.php5`, `.pht` for PHP, or `.jsp`/`.jspx`, `.asp`/`.aspx` for Java/.NET (PortSwigger)
- Windows NTFS Alternate Data Streams, _e.g._ `shell.asp:.jpg` or `shell.php::$DATA`: colon read as stream separator, file on disk carries extension before colon - reject any filename containing colon (`:`) (OWASP - Unrestricted File Upload)
- Generic bad regex not properly tested/reviewed. Don't build own logic w/o enough knowledge.

See [Input Validation CS](Input_Validation.md) to parse/process extension properly.

#### List Allowed Extensions

Use _business-critical_ extensions only; no _non-required_ extensions. E.g. system requires:

- image upload: allow one type agreed to fit business requirement;
- cv upload: allow `docx` and `pdf` extensions.

Per app needs, ensure **least harmful**, **lowest risk** file types.

#### Block Extensions

Identify potentially harmful file types; block extensions regarded harmful to service.

Blocking specific extensions = weak protection alone. Unrestricted File Upload vulnerability article describes attacker bypasses.

### Content-Type Validation

_Content-Type of uploaded files is user-provided → untrusted, trivially spoofed. Not for security reliance; quick check preventing users unintentionally uploading wrong type._

Besides extension, MIME-type check gives quick protection against simple file upload attacks.

Preferably allowlist; otherwise denylist.

### File Signature Validation

With [content-type validation](#content-type-validation), check file signature against expected file.

> Do not use alone; bypass pretty common and easy.

### Filename Safety

Filenames endanger system via unacceptable characters or special/restricted filenames. Windows: MSDN naming conventions guide. Wider filesystem overview: Wikipedia Filename page.

Essential: **random string** filename, e.g. UUID/GUID. If business needs filename: proper input validation for client-side (_e.g._ active content → XSS, CSRF) and back-end (_e.g._ special files overwrite/creation) vectors. Consider filename length limits of storing system; each has own. If user filenames required, consider:

- Implement maximum length
- Restrict characters to allowed subset, e.g. alphanumeric, hyphen, spaces, periods
    - Consider telling user what acceptable filename is.
    - Restrict leading periods (hidden files) and sequential periods (directory traversal).
    - Restrict leading hyphen or spaces → safer shell script processing of files.
    - If not possible, block-list dangerous characters that could endanger framework/system storing and using files.

Windows/NTFS: long filename may have 8.3 short name alias, depending on file system settings. Don't assume alias exists or has particular spelling. If overwrite/collision check validates only user-supplied long filename, attacker predicting short alias of existing sensitive file may reference it directly to overwrite it, bypassing exact-name or extension check. Server-side generated stored filename (above) removes risk: attacker no longer controls target file. Disabling short-name creation prevents new aliases; does not remove existing ones. Assess existing short names separately before relying on setting: Microsoft documents removal and compatibility checks, incl. backup precautions before removal.

### File Content Validation

Per [Public File Retrieval](#public-file-retrieval): file content can be malicious, inappropriate, illegal.

Per expected type, special content validation:

- **Images**: decode and re-encode to allowed image format, explicitly removing unnecessary metadata. Rewriting does not guarantee all malicious content removed; image processor itself handles untrusted input. Use up-to-date library w/ restricted formats, resource limits, sandboxing.
- **Microsoft documents**: Apache POI helps validate uploaded documents.
- **ZIP files** not recommended: can contain all file types, numerous attack vectors.

File Upload service should let users report illegal content, copyright owners report abuse.

Enough resources: manual file review in sandboxed environment before public release.

Automating review can help, but harsh process; study well before use. Some services (_e.g._ Virus Total) provide APIs scanning files against known malicious file hashes. Some frameworks validate raw content type against predefined file types, e.g. ASP.NET Drawing Library. Beware data leakage and information gathering by public services.

### File Storage Location

Choose location by security and business requirements. Points ordered by security priority, inclusive:

1. Store files on **different host**: complete segregation of duties between app serving user and host handling uploads/storage.
2. Store files **outside webroot**, administrative access only.
3. Store files **inside webroot**, write permissions only.
   - If read access required, proper controls a must (_e.g._ internal IP, authorized user, etc.)

Storing files in databases (studied manner) = additional technique. Sometimes used for automatic backup, non file-system attacks, permissions issues. Cost: possible performance issues, DB and backup storage considerations, SQLi exposure. Advised only when DBA on team and process shows improvement over file-system storage.

Attacker may upload web server config file (_e.g._ `.htaccess`, `web.config`) into upload directory. If server allows per-directory config overrides, file could change how directory handles file types, e.g. map harmless extension to server execution. Second defense layer: disable per-directory config overrides on upload directories at web server level (_e.g._ Apache `AllowOverride None`, locked IIS handler mappings), in addition to storing outside webroot.

> Some files emailed/processed after upload, not stored on server. Apply this sheet's security measures before any action on them.

### User Permissions

Before any file upload service accessed, validate uploading user on two levels:

- Authentication level
    - User registered or identifiable, to set restrictions/limits on upload capabilities
- Authorization level
    - User has appropriate permissions to access or modify files

### Filesystem Permissions

> Set file permissions on least privilege.

Store files so:

- Only allowed system users can read files
- Only required modes set on file
    - If execution required, scan file before running (best practice) to ensure no macros or hidden scripts.

### Upload and Download Limits

Set proper upload size limits to protect storage capacity. If system extracts/processes files, apply size limit after decompression, using secure methods to calculate zip files size. See Safely extract files from ZipInputStream (Java's input stream for ZIP files).

Set proper request limits for download service if available, protecting server from DoS.

## Java Code Snippets

Document Upload Protection repository by Dominique: certain document types in Java.

## References

- Microsoft: Upload Files in ASP.NET Core
- CWE-434: Unrestricted Upload of File with Dangerous Type
