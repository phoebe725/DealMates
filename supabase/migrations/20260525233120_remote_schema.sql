drop extension if exists "pg_net";


  create table "public"."messages" (
    "id" text not null,
    "plan_id" text not null,
    "sender_id" text not null,
    "sender_name" text not null,
    "text" text not null,
    "timestamp" timestamp with time zone default now(),
    "is_system" boolean default false
      );



  create table "public"."plans" (
    "id" text not null,
    "restaurant_id" uuid not null,
    "restaurant_name" text not null,
    "creator_id" text not null,
    "creator_name" text not null,
    "is_asap" boolean not null default false,
    "scheduled_at" timestamp without time zone not null,
    "needed_people" integer not null,
    "current_people" integer not null default 1,
    "member_ids" text[] default '{}'::text[],
    "purpose" text not null,
    "notes" text default ''::text,
    "expires_at" timestamp without time zone not null,
    "reported_by" text[] default '{}'::text[]
      );



  create table "public"."restaurants" (
    "id" uuid not null default gen_random_uuid(),
    "name" text not null,
    "created_at" timestamp with time zone default now(),
    "slug" text,
    "cuisine" text,
    "address" text,
    "image_url" text,
    "latitude" double precision,
    "longitude" double precision
      );



  create table "public"."users" (
    "id" text not null,
    "email" text,
    "display_name" text not null,
    "bio" text default ''::text,
    "is_anonymous" boolean default false,
    "blocked_users" text[] default '{}'::text[],
    "reported_plans" text[] default '{}'::text[],
    "created_at" timestamp without time zone default now(),
    "updated_at" timestamp without time zone default now()
      );


alter table "public"."users" enable row level security;

CREATE INDEX idx_messages_plan_id ON public.messages USING btree (plan_id);

CREATE INDEX idx_messages_timestamp ON public.messages USING btree ("timestamp");

CREATE INDEX idx_plans_expires_at ON public.plans USING btree (expires_at);

CREATE INDEX idx_plans_restaurant_id ON public.plans USING btree (restaurant_id);

CREATE INDEX idx_users_email ON public.users USING btree (email);

CREATE UNIQUE INDEX messages_pkey ON public.messages USING btree (id);

CREATE UNIQUE INDEX plans_pkey ON public.plans USING btree (id);

CREATE UNIQUE INDEX restaurants_pkey ON public.restaurants USING btree (id);

CREATE UNIQUE INDEX restaurants_slug_key ON public.restaurants USING btree (slug);

CREATE UNIQUE INDEX users_email_key ON public.users USING btree (email);

CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id);

alter table "public"."messages" add constraint "messages_pkey" PRIMARY KEY using index "messages_pkey";

alter table "public"."plans" add constraint "plans_pkey" PRIMARY KEY using index "plans_pkey";

alter table "public"."restaurants" add constraint "restaurants_pkey" PRIMARY KEY using index "restaurants_pkey";

alter table "public"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

alter table "public"."messages" add constraint "messages_plan_id_fkey" FOREIGN KEY (plan_id) REFERENCES public.plans(id) ON DELETE CASCADE not valid;

alter table "public"."messages" validate constraint "messages_plan_id_fkey";

alter table "public"."plans" add constraint "plans_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE not valid;

alter table "public"."plans" validate constraint "plans_restaurant_id_fkey";

alter table "public"."restaurants" add constraint "restaurants_slug_key" UNIQUE using index "restaurants_slug_key";

alter table "public"."users" add constraint "users_email_key" UNIQUE using index "users_email_key";

grant delete on table "public"."messages" to "anon";

grant insert on table "public"."messages" to "anon";

grant references on table "public"."messages" to "anon";

grant select on table "public"."messages" to "anon";

grant trigger on table "public"."messages" to "anon";

grant truncate on table "public"."messages" to "anon";

grant update on table "public"."messages" to "anon";

grant delete on table "public"."messages" to "authenticated";

grant insert on table "public"."messages" to "authenticated";

grant references on table "public"."messages" to "authenticated";

grant select on table "public"."messages" to "authenticated";

grant trigger on table "public"."messages" to "authenticated";

grant truncate on table "public"."messages" to "authenticated";

grant update on table "public"."messages" to "authenticated";

grant delete on table "public"."messages" to "service_role";

grant insert on table "public"."messages" to "service_role";

grant references on table "public"."messages" to "service_role";

grant select on table "public"."messages" to "service_role";

grant trigger on table "public"."messages" to "service_role";

grant truncate on table "public"."messages" to "service_role";

grant update on table "public"."messages" to "service_role";

grant delete on table "public"."plans" to "anon";

grant insert on table "public"."plans" to "anon";

grant references on table "public"."plans" to "anon";

grant select on table "public"."plans" to "anon";

grant trigger on table "public"."plans" to "anon";

grant truncate on table "public"."plans" to "anon";

grant update on table "public"."plans" to "anon";

grant delete on table "public"."plans" to "authenticated";

grant insert on table "public"."plans" to "authenticated";

grant references on table "public"."plans" to "authenticated";

grant select on table "public"."plans" to "authenticated";

grant trigger on table "public"."plans" to "authenticated";

grant truncate on table "public"."plans" to "authenticated";

grant update on table "public"."plans" to "authenticated";

grant delete on table "public"."plans" to "service_role";

grant insert on table "public"."plans" to "service_role";

grant references on table "public"."plans" to "service_role";

grant select on table "public"."plans" to "service_role";

grant trigger on table "public"."plans" to "service_role";

grant truncate on table "public"."plans" to "service_role";

grant update on table "public"."plans" to "service_role";

grant delete on table "public"."restaurants" to "anon";

grant insert on table "public"."restaurants" to "anon";

grant references on table "public"."restaurants" to "anon";

grant select on table "public"."restaurants" to "anon";

grant trigger on table "public"."restaurants" to "anon";

grant truncate on table "public"."restaurants" to "anon";

grant update on table "public"."restaurants" to "anon";

grant delete on table "public"."restaurants" to "authenticated";

grant insert on table "public"."restaurants" to "authenticated";

grant references on table "public"."restaurants" to "authenticated";

grant select on table "public"."restaurants" to "authenticated";

grant trigger on table "public"."restaurants" to "authenticated";

grant truncate on table "public"."restaurants" to "authenticated";

grant update on table "public"."restaurants" to "authenticated";

grant delete on table "public"."restaurants" to "service_role";

grant insert on table "public"."restaurants" to "service_role";

grant references on table "public"."restaurants" to "service_role";

grant select on table "public"."restaurants" to "service_role";

grant trigger on table "public"."restaurants" to "service_role";

grant truncate on table "public"."restaurants" to "service_role";

grant update on table "public"."restaurants" to "service_role";

grant delete on table "public"."users" to "anon";

grant insert on table "public"."users" to "anon";

grant references on table "public"."users" to "anon";

grant select on table "public"."users" to "anon";

grant trigger on table "public"."users" to "anon";

grant truncate on table "public"."users" to "anon";

grant update on table "public"."users" to "anon";

grant delete on table "public"."users" to "authenticated";

grant insert on table "public"."users" to "authenticated";

grant references on table "public"."users" to "authenticated";

grant select on table "public"."users" to "authenticated";

grant trigger on table "public"."users" to "authenticated";

grant truncate on table "public"."users" to "authenticated";

grant update on table "public"."users" to "authenticated";

grant delete on table "public"."users" to "service_role";

grant insert on table "public"."users" to "service_role";

grant references on table "public"."users" to "service_role";

grant select on table "public"."users" to "service_role";

grant trigger on table "public"."users" to "service_role";

grant truncate on table "public"."users" to "service_role";

grant update on table "public"."users" to "service_role";


  create policy "Allow insert messages"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid())::text = sender_id));



  create policy "Allow read messages"
  on "public"."messages"
  as permissive
  for select
  to public
using (true);



  create policy "Allow insert plans"
  on "public"."plans"
  as permissive
  for insert
  to public
with check (true);



  create policy "Allow read plans"
  on "public"."plans"
  as permissive
  for select
  to public
using (true);



  create policy "Allow update plans"
  on "public"."plans"
  as permissive
  for update
  to public
using (true)
with check (true);



  create policy "users_insert"
  on "public"."users"
  as permissive
  for insert
  to public
with check (true);



  create policy "users_read_all"
  on "public"."users"
  as permissive
  for select
  to public
using (true);



  create policy "users_update_own"
  on "public"."users"
  as permissive
  for update
  to public
using (((auth.uid())::text = id))
with check (((auth.uid())::text = id));



