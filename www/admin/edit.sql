-- Only the admin may use the editor. Caddy already asked for the login; this re-checks it inside
-- SQLPage, against an argon2id hash the container computes at start (the plaintext is not visible here).
SELECT 'authentication' AS component,
    CASE WHEN sqlpage.basic_auth_username() = sqlpage.environment_variable('ADMIN_USERNAME')
         THEN sqlpage.environment_variable('ADMIN_PASSWORD_HASH') END AS password_hash,
    sqlpage.basic_auth_password() AS password;

SELECT 'form' AS component,
    CASE WHEN $path IS NULL THEN 'New page' ELSE 'Editing ' || $path END AS title,
    'save.sql' AS action,
    'Save' AS validate;
SELECT 'path' AS name, 'text' AS type, 'Path' AS label, $path AS value, TRUE AS required,
    'hello.sql' AS placeholder,
    'Served at /<path>. Letters, digits, _ - . and / only; .sql files run as SQLPage pages.' AS description;
SELECT 'contents' AS name, 'textarea' AS type, 'Contents' AS label, 20 AS rows,
    (SELECT convert_from(contents, 'UTF8') FROM sqlpage_files WHERE path = $path AND substring(contents FROM 1 FOR 26) <> convert_to('-- sqlpage-railway:deleted', 'UTF8')) AS value,
    'SELECT ''text'' AS component, ''Hello, world!'' AS contents;' AS placeholder;

SELECT 'form' AS component, 'Delete this page' AS title, 'delete.sql' AS action,
    'Delete ' || $path AS validate, 'red' AS validate_color
WHERE $path IS NOT NULL AND EXISTS (SELECT 1 FROM sqlpage_files WHERE path = $path AND substring(contents FROM 1 FOR 26) <> convert_to('-- sqlpage-railway:deleted', 'UTF8'));
SELECT 'path' AS name, 'hidden' AS type, $path AS value
WHERE $path IS NOT NULL AND EXISTS (SELECT 1 FROM sqlpage_files WHERE path = $path AND substring(contents FROM 1 FOR 26) <> convert_to('-- sqlpage-railway:deleted', 'UTF8'));
SELECT 'confirm' AS name, 'checkbox' AS type, 'yes' AS value, 'Yes, delete it' AS label, TRUE AS required
WHERE $path IS NOT NULL AND EXISTS (SELECT 1 FROM sqlpage_files WHERE path = $path AND substring(contents FROM 1 FOR 26) <> convert_to('-- sqlpage-railway:deleted', 'UTF8'));

SELECT 'button' AS component;
SELECT 'Back to all pages' AS title, 'index.sql' AS link, 'arrow-left' AS icon;
