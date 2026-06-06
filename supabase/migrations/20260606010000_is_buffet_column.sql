-- AYCE / Buffet is a property of a restaurant, not a cuisine. Store it as a
-- first-class boolean column (source of truth) instead of a hardcoded ID list
-- duplicated across the web and iOS clients.
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_buffet BOOLEAN NOT NULL DEFAULT false;

-- Backfill: the set previously hardcoded as buffetRestaurantIDs / BUFFET_IDS
-- in the clients. Going forward, flip this column instead of editing code.
UPDATE restaurants SET is_buffet = true WHERE id IN (
  'e6f9a2b3-3a4d-4e7f-6c8b-9e1d3e5a8c1e', -- Yauatcha — Soho
  'a2b56d7e-8c9f-4a3b-2e4d-5a6f8a1c4e6a', -- Happy Lamb — Bayswater
  'a2b5c7d8-8c9f-4a3b-2e4d-5a6f8a1c4e6a', -- Eat Tokyo — Soho
  'fe3c6f9d-3504-4b30-ac40-087e7819031e', -- Haidilao — O2
  '7ffaadc0-1c28-4305-a43f-8a7b57b90249', -- Haidilao — Piccadilly
  '52a665e1-fdf3-49c1-81ba-c3434d43835a', -- Da Long Yi — Fitzrovia
  '8833e03a-f43a-4974-88de-9f18ac04cb6a', -- Ning's — Chinatown
  '105b7fbd-e54c-4ca7-bfb6-5acb52e36ee2', -- Ning's — Tottenham Street
  'fa0e7619-0c96-44ec-b61f-02ffe33d8b2b', -- Ai Sushi — North Finchley
  '098dcf82-89a5-4c0e-9671-a58f2d413efb', -- Mu Yang Ren — Shepherd's Bush
  '75ce5b67-52c1-4492-8dcd-367295d99fdb', -- Sumiya — Shoreditch
  '7540f6f8-4f57-4f71-94ce-103950805921', -- Er Mei — Chinatown
  '28b60ce5-9af5-40dd-ac1d-41d30da73368', -- Mr Charcoal — Lambeth North
  '955e387c-ee1f-4a77-8c8b-de80c5fb7595', -- High Yaki — Chinatown
  '2272f145-26e1-43c3-8316-7f8bfed56b3a', -- Sanshun BBQ Hotpot — Hammersmith
  'e0f7cf51-cd68-40ef-914d-54da5499c8b5', -- DAIU — Wembley
  '2e905009-8485-4deb-8451-ae1847e6b834', -- DAIU — Wimbledon
  'cdea95aa-de47-4d48-856a-3765065cd97f', -- DAIU — Croydon
  '8be0d9a1-308a-4626-bff2-5401e0620139', -- Hotpot Master — Canary Wharf
  '906bff7d-4b9b-4251-9347-4bee870bf0c6', -- Chengdu Chengdu — Leicester Square
  '1b52d32d-eeb0-471a-94bf-2fc736f75cf1', -- Real Beijing Food House — Chinatown
  '67be35be-d371-4632-926d-1481b48fee37', -- New China — Chinatown
  'f0b8f931-f549-48a0-8487-c5c196d04c47', -- Cheli — Elephant Park
  '1a6f9e8f-3e93-4e72-aafb-5617310bbe3b', -- Happy Lamb — Holborn
  '1aa93e5c-001e-44ae-bbb0-8da6d34f4679', -- NIU Hot Pot — Spitalfields
  '166f8eaa-f7fb-4d87-abf4-5a74aa6f6d01', -- Master Li — Earl's Court
  '9c42c076-792f-4d8f-a119-068c7d689256', -- Pao Men Shi Jia — Spitalfields
  'e210ad68-01bd-4b80-a781-048cd6c349c5'  -- ZhangLiang Malatang — Liverpool Street
);
