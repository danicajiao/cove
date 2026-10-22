-- Seed catalog.media — one primary image per item.
-- media_key values are the image storage paths carried over from Firestore.
-- width/height are 0 — to be backfilled by the image pipeline.

INSERT INTO catalog.media (id, item_id, media_key, role, sort_order, width, height)
VALUES (
    'f4000001-abcd-0000-0000-000000000001',
    'f3000001-1234-0000-0000-000000000001',
    'images/198bd677d60fe63e71f2364a5b2f8b7f9dc390ab1a835179d37cc2b24a6f5680.webp',
    'primary', 0, 0, 0
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.media (id, item_id, media_key, role, sort_order, width, height)
VALUES (
    'f4000001-abcd-0000-0000-000000000002',
    'f3000001-1234-0000-0000-000000000002',
    'images/782551befe683f93faab8047495213e78a8d8f5f74a1cf57e727fb09beed34e3.webp',
    'primary', 0, 0, 0
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.media (id, item_id, media_key, role, sort_order, width, height)
VALUES (
    'f4000001-abcd-0000-0000-000000000003',
    'f3000001-1234-0000-0000-000000000003',
    'images/c700ae97872641c582c4dfdfa3769a0645cbfe4db33203b7e584a8e822a0d6a0.webp',
    'primary', 0, 0, 0
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO catalog.media (id, item_id, media_key, role, sort_order, width, height)
VALUES (
    'f4000001-abcd-0000-0000-000000000004',
    'f3000001-1234-0000-0000-000000000004',
    'images/4b57be3e93a3aadd9df795b69490ef787647c9158b2dfbfdebd2a94c45680924.webp',
    'primary', 0, 0, 0
)
ON CONFLICT (id) DO NOTHING;
