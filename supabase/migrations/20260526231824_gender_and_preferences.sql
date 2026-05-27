alter table public.users
    add column if not exists gender text;

alter table public.plans
    add column if not exists gender_preference text default 'any';

update public.plans set gender_preference = 'any' where gender_preference is null;
