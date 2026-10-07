-- Only the admin may use the editor. Caddy already asked for the login; this re-checks it inside
-- SQLPage, against an argon2id hash the container computes at start (the plaintext is not visible here).
SELECT 'authentication' AS component,
    CASE WHEN sqlpage.basic_auth_username() = sqlpage.environment_variable('ADMIN_USERNAME')
         THEN sqlpage.environment_variable('ADMIN_PASSWORD_HASH') END AS password_hash,
    sqlpage.basic_auth_password() AS password;

-- Browsers replay basic-auth credentials on cross-site requests, so a write must come from a form
-- on this site: POST only, with an Origin header naming this host.
SET same_origin = CASE
    WHEN sqlpage.request_method() = 'POST'
     AND split_part(coalesce(sqlpage.header('origin'), ''), '://', 2) = sqlpage.header('host')
    THEN 'yes' ELSE 'no' END;
SELECT 'status_code' AS component, 403 AS status WHERE $same_origin <> 'yes';
SELECT 'text' AS component, 'Refused: changes must be submitted from the editor on this site.' AS contents
WHERE $same_origin <> 'yes';

SET valid_path = CASE
    WHEN :path ~ '^[A-Za-z0-9_][A-Za-z0-9_./-]{0,200}$' AND position('..' IN :path) = 0
     AND lower(split_part(:path, '/', 1)) NOT IN ('admin', 'sqlpage') AND lower(:path) <> 'healthz.sql'
    THEN 'yes' ELSE 'no' END;
SELECT 'status_code' AS component, 400 AS status WHERE $same_origin = 'yes' AND $valid_path <> 'yes';
SELECT 'text' AS component,
    'Invalid path. Use letters, digits, _ - . and /, not starting with admin/ or sqlpage/, without "..".' AS contents
WHERE $same_origin = 'yes' AND $valid_path <> 'yes';

INSERT INTO sqlpage_files (path, contents)
SELECT :path, convert_to(coalesce(:contents, ''), 'UTF8')
WHERE $same_origin = 'yes' AND $valid_path = 'yes'
ON CONFLICT (path) DO UPDATE SET contents = excluded.contents
RETURNING 'redirect' AS component, 'index.sql?saved=' || path AS link;
