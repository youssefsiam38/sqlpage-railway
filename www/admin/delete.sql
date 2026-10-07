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

-- SQLPage caches compiled .sql pages and only notices a page CHANGED (last_modified moving forward),
-- not a page that disappeared: a deleted row would keep being served until the next restart. So a
-- .sql page is replaced by a tombstone that answers 404 (hidden from the editor's list, and
-- overwritten if you save that path again); other files are not cached and are deleted outright.
UPDATE sqlpage_files
SET contents = convert_to('-- sqlpage-railway:deleted
SELECT ''status_code'' AS component, 404 AS status;
SELECT ''text'' AS component, ''Page not found.'' AS contents;
', 'UTF8')
WHERE path = :path AND path LIKE '%.sql' AND :confirm = 'yes' AND $same_origin = 'yes'
RETURNING 'redirect' AS component, 'index.sql?deleted=' || path AS link;

DELETE FROM sqlpage_files
WHERE path = :path AND path NOT LIKE '%.sql' AND :confirm = 'yes' AND $same_origin = 'yes'
RETURNING 'redirect' AS component, 'index.sql?deleted=' || path AS link;

SELECT 'text' AS component, 'Nothing deleted: tick the confirmation box.' AS contents
WHERE $same_origin = 'yes';
SELECT 'button' AS component WHERE $same_origin = 'yes';
SELECT 'Back to all pages' AS title, 'index.sql' AS link WHERE $same_origin = 'yes';
