-- Unauthenticated platform healthcheck, served at /healthz by the front door. It proves the database
-- answers and the migrations ran, and returns nothing else.
SELECT 'json' AS component, json_build_object('status', 'ok') AS contents
WHERE (SELECT count(*) FROM sqlpage_files) >= 0;
