-- Only the admin may use the editor. Caddy already asked for the login; this re-checks it inside
-- SQLPage, against an argon2id hash the container computes at start (the plaintext is not visible here).
SELECT 'authentication' AS component,
    CASE WHEN sqlpage.basic_auth_username() = sqlpage.environment_variable('ADMIN_USERNAME')
         THEN sqlpage.environment_variable('ADMIN_PASSWORD_HASH') END AS password_hash,
    sqlpage.basic_auth_password() AS password;

SELECT 'alert' AS component, 'Saved ' || $saved AS title, 'green' AS color, 'check' AS icon,
    'View it' AS link_text, '/' || $saved AS link
WHERE $saved IS NOT NULL;
SELECT 'alert' AS component, 'Deleted ' || $deleted AS title, 'yellow' AS color, 'trash' AS icon
WHERE $deleted IS NOT NULL;

SELECT 'list' AS component,
    'Pages stored in the database' AS title,
    'No pages in the database yet.' AS empty_title;
SELECT path AS title,
    '/' || path AS link,
    'Last modified ' || to_char(last_modified, 'YYYY-MM-DD HH24:MI') || ' UTC, ' || octet_length(contents) || ' bytes' AS description,
    sqlpage.link('edit.sql', json_build_object('path', path)) AS edit_link
FROM sqlpage_files
WHERE substring(contents FROM 1 FOR 26) <> convert_to('-- sqlpage-railway:deleted', 'UTF8')
ORDER BY path;
SELECT 'New page' AS title, 'edit.sql' AS link, 'file-plus' AS icon, 'green' AS color,
    'Create a new .sql page (or any other file) in the database' AS description;

SELECT 'list' AS component, 'Tables in the public schema' AS title;
SELECT table_name AS title, 'table' AS icon
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT 'text' AS component,
    'Pages are rows in the sqlpage_files table (path, contents, last_modified). The /admin/ pages themselves are files in the container image and cannot be changed from here. Create tables with a page that runs CREATE TABLE once, or from Railway''s database tools. SQLPage documentation: [sql-page.com](https://sql-page.com).' AS contents_md;
