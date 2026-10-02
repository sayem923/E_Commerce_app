# MegaMart — Updates Log

## নতুন (এই round): Multiple Product Images

আগে প্রতিটা প্রোডাক্টের জন্য শুধু একটা ছবি রাখা যেত। এখন vendor একসাথে
একাধিক ছবি আপলোড করতে পারবেন, আর customer সোয়াইপ করে সেগুলো দেখতে
পারবে (Daraz/Amazon-এর মতো)।

### কী বদলালো
- **`vendor_dashboard.dart`** — নতুন প্রোডাক্ট পোস্ট করার সময় এখন
  একসাথে একাধিক ছবি সিলেক্ট করা যাবে; প্রথম ছবিটা "Cover" হিসেবে চিহ্নিত
  থাকে, যেকোনো ছবি বাদ দেওয়া যাবে পোস্ট করার আগেই
- **`product_details_page.dart`** — এখন static ছবির বদলে swipeable
  carousel দেখাবে (একাধিক ছবি থাকলে), নিচে dot indicator থাকবে
- **`my_products_page.dart`** (Edit Product) — existing ছবি দেখা যাবে,
  নতুন ছবি যোগ/মুছে ফেলা যাবে, সবকিছু Edit dialog-এর ভেতর থেকেই

### Backward compatibility
`image_url` কলাম (single, cover ছবি) আগের মতোই আছে — Cart, Orders,
Wishlist, product card এখনো এই একটা ছবিই দেখায়। নতুন `image_urls`
(array) কলাম শুধু product details পেজের gallery-র জন্য।

### ⚠️ করণীয় (SQL)
`rls_policies.sql`-এ নতুন এক লাইন যোগ হয়েছে:
```sql
alter table products add column if not exists image_urls text[] default '{}';
```
পুরো `rls_policies.sql` ফাইল আবার Supabase SQL Editor-এ চালিয়ে নিন
(আগের সব policy/function অপরিবর্তিত থাকবে, শুধু এই নতুন কলামটা যোগ হবে)।

আগে পোস্ট করা প্রোডাক্টগুলোর `image_urls` খালি থাকবে — সেগুলো আগের
একটা ছবি দিয়েই কাজ করবে (fallback ব্যবস্থা কোডে আছে), এডিট করে নতুন
ছবি যোগ করলে gallery হয়ে যাবে।

কোনো নতুন Flutter package লাগেনি এই round-এ (carousel_slider_plus,
image_picker আগে থেকেই ছিল)।

---

## নতুন (আগের round): Product Reviews & Ratings

নতুন `lib/review_widgets.dart` — পুরো review/rating সিস্টেম:
- **StarRatingDisplay** — read-only স্টার (product card, product details, review list)
- **StarRatingInput** — রিভিউ লেখার সময় ট্যাপ করে ১-৫ স্টার বাছার জন্য
- **ReviewsSection** — Product Details পেজে বসানো পুরো section: average
  rating সামারি, review list (real-time), আর "Write a Review" ফর্ম

### একটা গুরুত্বপূর্ণ নিয়ম
**শুধুমাত্র যারা প্রোডাক্টটা কিনে "Completed" পেয়েছেন তারাই রিভিউ দিতে
পারবেন** — এটা RLS policy দিয়ে database-level এ enforce করা, spam/fake
review ঠেকানোর জন্য। কেউ না কিনে রিভিউ দেওয়ার চেষ্টা করলে বন্ধুসুলভ
error message দেখাবে।

### Rating badge কোথায় কোথায় দেখাবে
- Product Details পেজে (নাম-এর নিচে, বড় star + review count)
- Home page-এর product card-এ (ছোট star + count, শুধু review থাকলে)
- Vendor-এর নিজের product view পেজেও (read-only, নিজে রিভিউ দিতে পারবেন না)

### ⚠️ করণীয় (SQL)
`rls_policies.sql` ফাইলে নতুন যোগ হয়েছে:
- `products` টেবিলে `avg_rating`, `review_count` কলাম (cache করে রাখা,
  বারবার aggregate query চালাতে হয় না)
- নতুন `reviews` টেবিল + RLS policy (একজন user একটা product-এ একটাই
  রিভিউ দিতে পারবে — `unique(product_id, user_id)`)
- Trigger যেটা review add/edit/delete হলে automatically
  `avg_rating`/`review_count` আপডেট করে দেয়
- Realtime enable করা হয়েছে যাতে review list live আপডেট হয়

**`rls_policies.sql`-এর পুরো (আপডেটেড) content আবার Supabase SQL Editor-এ
চালিয়ে নিন।** নতুন কোনো Flutter package লাগেনি এই round-এ, শুধু `flutter
pub get` না চালালেও চলবে (কিন্তু চালিয়ে নেওয়া নিরাপদ)।

---

## নতুন (আগের round): Loading Skeleton (Shimmer)

আগে যেকোনো পেজ লোড হওয়ার সময় শুধু মাঝখানে একটা ঘোরানো spinner
দেখাতো। এখন সেই জায়গায় **আসল content-এর আকৃতির ধূসর "skeleton"**
দেখাবে যেটা shimmer (হালকা চকচক) effect দিয়ে animate হয় — Facebook,
Instagram-এর মতো — তারপর আসল ডাটা এলে সেই জায়গায় বসে যায়।

নতুন `lib/skeleton_widgets.dart` — reusable skeleton widget:
- **`ProductGridSkeleton`** — product grid card-এর আকৃতিতে (home page)
- **`ListSkeleton`** — সারিবদ্ধ card list-এর আকৃতিতে (cart, orders,
  wishlist, my products, vendor orders, notifications)

### কোথায় কোথায় বসানো হলো
`home_page.dart`, `user_home_page.dart` (product grid), `cart_page.dart`,
`order_page.dart`, `wishlist_page.dart`, `my_products_page.dart`,
`vendor_orders_page.dart`, `notifications_page.dart`

### ⚠️ করণীয়
নতুন package `shimmer` `pubspec.yaml`-এ যোগ হয়েছে। zip extract করার পর:
```
flutter pub get
```
কোনো Supabase/SQL change লাগবে না।

---

## নতুন (আগের round): Sales Analytics (Vendor Dashboard)

নতুন `lib/sales_analytics_page.dart` — vendor তার নিজের Accept-করা order
গুলো থেকে বিক্রি সম্পর্কিত পরিসংখ্যান দেখতে পারবে:

- **Summary cards**: Total Revenue (শুধু Completed order থেকে), Total
  Orders, আর status অনুযায়ী breakdown (Completed/Pending/Processing/Cancelled)
- **গত ৭ দিনের bar chart** — প্রতিদিনের revenue trend
- **Best-selling products** — কোন প্রোডাক্ট সবচেয়ে বেশি বিক্রি হচ্ছে (top ৫)

### কোথা থেকে খুলবেন
- Vendor Panel (`vendor_dashboard.dart`) এর AppBar-এ 📊 আইকন
- Vendor Orders পেজের AppBar-এও 📊 আইকন
- Home page-এর drawer-এ "Sales Analytics" মেনু আইটেম

### ⚠️ করণীয়
নতুন একটা package (`fl_chart`) `pubspec.yaml`-এ যোগ করা হয়েছে চার্ট
আঁকার জন্য। zip extract করার পর অবশ্যই চালান:
```
flutter pub get
```
কোনো নতুন SQL/Supabase change লাগবে না — এটা existing `orders` টেবিলের
ডাটা থেকেই হিসাব করে।

---

## নতুন (আগের round): Order History Filter/Search

### Customer-এর Orders পেজ (`order_page.dart`)
- উপরে status অনুযায়ী filter chip: **All / Pending / Processing /
  Completed / Cancelled**
- AppBar-এ একটা calendar icon — নির্দিষ্ট তারিখের রেঞ্জের order দেখতে
  পারবেন, পাশে clear (✕) বাটন দিয়ে filter সরানো যাবে

### Vendor-এর My Orders ট্যাব (`vendor_orders_page.dart`)
- একই রকম status filter chip
- সাথে একটা search বার — Order ID বা Product নাম দিয়ে খুঁজতে পারবেন

কোনো নতুন SQL/schema লাগবে না — এটা সম্পূর্ণ client-side filtering,
আগে থেকে থাকা order data-র উপর কাজ করে।

---

## আগের round: Order Auto-Cancel (স্টক ফেরত সহ)

### সমস্যা কী ছিল
৩০ মিনিট পার হয়ে যাওয়া "pending" order আগে শুধু UI-তে "EXPIRED" দেখাতো —
কিন্তু database-এ status বদলাতো না, আর সেই order-এর জন্য কমানো stock-ও
কখনো ফেরত আসতো না। মানে বারবার order দিয়ে payment না করলে stock ধীরে
ধীরে "লিক" হয়ে যাচ্ছিল।

### কী করা হলো
`rls_policies.sql` ফাইলে নতুন যোগ হয়েছে:
- **`cancel_expired_orders()`** — একটা function যেটা এখনো "pending"
  (কোনো vendor Accept করেনি) এবং সময়সীমা পার হয়ে যাওয়া সব order
  খুঁজে বের করে, `status = 'cancelled'` করে দেয়, product-এর stock
  ফেরত দেয়, আর customer-কে notification পাঠায়
- **`pg_cron` schedule** — প্রতি ১ মিনিটে automatically এই function
  চালানোর জন্য

### ⚠️ করণীয়
১. `rls_policies.sql`-এর পুরো কনটেন্ট (নতুন অংশসহ) আবার Supabase SQL
   Editor-এ চালিয়ে নিন
২. **pg_cron extension enable আছে কিনা চেক করুন** — Supabase Dashboard →
   Database → Extensions → "pg_cron" সার্চ করে টগল ON করুন (অনেক
   প্রজেক্টে এটা আগে থেকেই enabled থাকে, তাহলে কিছু করতে হবে না)

### Fallback (pg_cron কাজ না করলেও চলবে)
এমনকি pg_cron ছাড়াও এটা কাজ করবে — কারণ Flutter কোডে (`order_page.dart`,
`vendor_orders_page.dart`) পেজ খোলার সময় `cancel_expired_orders()`
নিজে থেকেই একবার call হয়। মানে customer বা vendor যখনই Orders পেজ
খুলবে, তখন expired order গুলো clean up হয়ে যাবে — pg_cron শুধু এটাকে
real-time-এর কাছাকাছি করে (প্রতি মিনিটে, পেজ না খুললেও)।

---

## নতুন (আগের round): RLS Security Audit + Inventory/Stock Tracking

### ১. RLS (Row Level Security) — নিরাপত্তা
প্রজেক্ট root-এ নতুন ফাইল **`rls_policies.sql`** যোগ করা হয়েছে (এটা `lib/`
এর বাইরে, কারণ এটা Dart code না)। এতে `cart`, `products`, `profiles`,
`orders`, `wishlist`, `notifications`, `banners` — প্রতিটা টেবিলের জন্য
সঠিক scope করা policy আছে:

- **cart, wishlist** — user শুধু নিজেরটাই দেখতে/এডিট/ডিলিট করতে পারবে
- **products** — সবাই browse করতে পারবে, কিন্তু শুধু vendor নিজের প্রোডাক্ট
  বানাতে/বদলাতে/মুছতে পারবে
- **orders** — customer নিজের order দেখবে/বানাবে/মুছবে; vendor শুধু নিজের
  Accept-করা অথবা এখনো unassigned (broadcast) order দেখতে/আপডেট করতে
  পারবে — এবং শুধু `role = 'vendor'` হলেই order আপডেট করা যাবে
- **profiles** — সবাই দেখতে পারবে (নাম দেখানোর জন্য), কিন্তু শুধু নিজের
  প্রোফাইল এডিট করতে পারবে
- **notifications** — user শুধু নিজেরটা দেখবে/read মার্ক করবে

**⚠️ করণীয়:** `rls_policies.sql` এর পুরো কন্টেন্ট Supabase SQL Editor-এ
একবারে paste করে Run করুন। এটা `drop policy if exists` দিয়ে শুরু হওয়ায়
আগে যা-ই policy থাকুক না কেন safely replace হয়ে যাবে, দুইবার চালালেও
সমস্যা নেই।

### ২. Inventory / Stock Tracking
- Vendor নতুন প্রোডাক্ট পোস্ট করার সময় এখন **Stock Quantity** লিখতে হবে
  (`vendor_dashboard.dart`)
- **My Products** পেজে stock দেখা যাবে ও এডিট করা যাবে (`my_products_page.dart`)
- Product Details পেজে **"In Stock (X available)"** বা **"Out of Stock"**
  badge দেখাবে, stock ০ হলে Add to Cart/Buy Now বাটন disable হয়ে যাবে
- Home page-এর product card-এ stock ০ হলে **"OUT OF STOCK"** overlay
  দেখাবে
- Order করার সময় (Cart checkout ও Buy Now দুটোতেই) stock **atomically**
  কমানো হয় — একটা বিশেষ Postgres function (`decrement_stock`) দিয়ে, যাতে
  দুইজন customer একই মুহূর্তে শেষ পিসটা কিনতে চাইলেও stock কখনো নেগেটিভ
  না হয়ে যায় এবং একজনই সফল হয়
- Cart checkout-এ কোনো item stock-এ না থাকলে সেটা বাদ দিয়ে বাকি item গুলোর
  order হয়ে যাবে, আর কোন item(গুলো) বাদ পড়লো সেটা message-এ দেখাবে

**⚠️ করণীয়:** `rls_policies.sql` ফাইলের নিচের দিকে "Stock Tracking" অংশে
`products` টেবিলে `stock` কলাম যোগ করা ও `decrement_stock` function
বানানোর SQL আছে — এটাও একই সাথে চালিয়ে নিন (RLS SQL-এর সাথেই একবারে
পুরো ফাইল Run করলে দুটোই হয়ে যাবে)।

**নতুন প্রোডাক্টে stock বসবে, কিন্তু আগে থেকে পোস্ট করা প্রোডাক্টগুলোর
stock ডিফল্ট `0` হবে** (`alter table ... default 0` এর কারণে) — মানে
পুরনো প্রোডাক্ট সব "Out of Stock" দেখাবে যতক্ষণ না আপনি My Products
পেজে গিয়ে প্রতিটার stock ম্যানুয়ালি বসিয়ে দিচ্ছেন। চাইলে বাল্কে একটা
ডিফল্ট সংখ্যা বসাতে পারেন:
```sql
update products set stock = 10 where stock = 0;
```

---



### কেন এই পরিবর্তন
আগে প্রতিটা order নির্দিষ্ট একটা vendor-এর সাথে বাঁধা ছিল (product যে vendor
পোস্ট করেছিল)। কিন্তু সেই vendor account delete হয়ে গেলে বা কোনো কারণে
`vendor_id` invalid হলে **"foreign key constraint" error** দিয়ে পুরো order
ব্যর্থ হয়ে যাচ্ছিল।

আপনি চেয়েছেন: order এলে **সব vendor** notification পাবে, যে vendor আগে
"Accept" করবে **সে-ই** সেই order-এর delivery-র দায়িত্ব নেবে — product কোন
vendor পোস্ট করেছিল তার সাথে আর order-এর সম্পর্ক থাকবে না।

### ⚠️ প্রথমে এই SQL চালান (এটা ছাড়া app এ order দিলে আগের মতোই error আসবে)

```sql
-- vendor_id nullable করা — order তৈরির সময় আর বাধ্যতামূলক না
alter table orders alter column vendor_id drop not null;
```

### তারপর নোটিফিকেশন trigger আপডেট করুন
আগে যে `notify_vendor_new_order` trigger বানিয়েছিলেন সেটা শুধু একজন
নির্দিষ্ট vendor-কে notify করতো। এখন এটা **সব vendor**-কে notify করার
জন্য replace করে দিন:

```sql
create or replace function notify_all_vendors_new_order()
returns trigger
language plpgsql
security definer
as $$
declare
  v record;
begin
  for v in select id from profiles where role = 'vendor' loop
    insert into notifications (user_id, title, body, order_id)
    values (
      v.id,
      'নতুন অর্ডার এসেছে!',
      coalesce(new.product_name, 'একটি প্রোডাক্ট') || ' - ' || coalesce(new.quantity::text, '1') || ' পিস অর্ডার হয়েছে। Accept করতে Orders পেজ দেখুন।',
      new.id
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_notify_vendor_new_order on orders;
create trigger trg_notify_vendor_new_order
after insert on orders
for each row execute function notify_all_vendors_new_order();
```

### কোড-এ যা বদলেছে
- `cart_page.dart`, `product_details_page.dart` — order/cart insert করার
  সময় আর `vendor_id` পাঠানো হয় না, আর "Vendor ID নেই" error/block-ও নেই
- `vendor_orders_page.dart` — এখন **২টা ট্যাব**:
  - **My Orders** — যেসব order এই vendor Accept করেছেন (আগের মতোই status
    বদলানো, payment verify করা যাবে)
  - **Available** — যেসব order এখনো কেউ Accept করেনি, সবাই দেখতে পাবে,
    "Accept Order" বাটনে ক্লিক করলে সেটা তার হয়ে যাবে
  - Accept করার সময় race-condition safe update ব্যবহার করা হয়েছে —
    দুইজন vendor একই সময়ে Accept করার চেষ্টা করলে যে আগে DB-তে পৌঁছাবে
    সে-ই পাবে, অন্যজন "অন্য vendor আগেই নিয়ে নিয়েছে" মেসেজ দেখবে

### পুরনো data নিয়ে একটা কথা
এর আগে যেসব order-এ ভুল/delete-হওয়া vendor_id বসে গিয়েছিল, সেগুলো ঠিক
করতে চাইলে:
```sql
update orders set vendor_id = null, status = 'pending'
where vendor_id not in (select id from profiles);
```
এটা চালালে সেই orphaned order গুলো আবার "Available" ট্যাবে চলে আসবে,
যেকোনো vendor Accept করতে পারবে।

---

## নতুন (আগের round): Payment (Manual bKash/Nagad) + In-app Notifications

### ⚠️ যা বাস্তবতা বোঝা দরকার
- **আসল bKash/Nagad Payment Gateway API** (auto-verify, instant confirm) নিতে
  হলে তাদের Merchant Account লাগবে (App Key/Secret, username/password) এবং
  সেই credential দিয়ে call করার জন্য একটা backend (Supabase Edge Function) —
  merchant credential কখনো client app-এ রাখা যায় না। এটা আমি করে দিতে পারিনি
  কারণ merchant account আপনার, আমার কাছে নেই।
- **Push Notification** (app বন্ধ থাকলেও notification আসা) করতে হলে
  Firebase project লাগবে (google-services.json / GoogleService-Info.plist,
  যেগুলো আপনার নিজের Firebase console থেকে জেনারেট হয়)। সেটাও আমি করে
  দিতে পারিনি।

তার বদলে যেটা **এখনই সম্পূর্ণ কাজ করবে** সেটা বানিয়ে দিয়েছি:

### Payment (Manual verification flow)
- Checkout-এ (Cart বা Buy Now) এখন Payment Method বেছে নেওয়ার dialog আসবে:
  **Cash on Delivery / bKash / Nagad**
- bKash/Nagad বাছলে `lib/payment_config.dart`-এ দেওয়া নাম্বার দেখাবে,
  customer সেই নাম্বারে টাকা পাঠিয়ে নিজের নাম্বার ও Transaction ID (TrxID)
  লিখে অর্ডার confirm করবে
- Vendor তার Orders পেজে (`vendor_orders_page.dart`) payment method,
  TrxID, এবং status দেখতে পাবে — TrxID bKash/Nagad app-এ মিলিয়ে
  "Verify" বাটনে ক্লিক করলে `payment_status` = `verified` হয়ে যাবে
- Customer নিজের Orders পেজেও payment status দেখতে পাবে

**যা করতে হবে — `lib/payment_config.dart` খুলে আপনার আসল bKash/Nagad
নাম্বার বসিয়ে দিন** (এখন placeholder `01XXXXXXXXX` আছে)।

**Supabase-এ SQL চালাতে হবে** (orders টেবিলে নতুন কলাম):
```sql
alter table orders add column payment_method text default 'COD';
alter table orders add column payment_status text default 'unpaid';
alter table orders add column transaction_id text;
```

### In-app Notifications
নতুন `lib/notifications_page.dart` — user/vendor app খুললে বা Notifications
ট্যাবে গেলে (vendor home-এ bottom-bar-এর bell icon, user home-এ drawer-এর
"Notifications") তাদের notification list দেখাবে, unread count এর লাল
badge bell icon-এর উপরে দেখাবে, real-time এ নতুন notification আসলে
সাথে সাথে দেখাবে।

**Supabase-এ এই পুরো SQL block চালান** (নতুন টেবিল + trigger, যেটা
automatic notification তৈরি করবে):
```sql
-- ১. Notifications টেবিল
create table notifications (
  id bigint generated by default as identity primary key,
  user_id uuid not null references auth.users(id),
  title text,
  body text,
  order_id bigint,
  is_read boolean default false,
  created_at timestamptz default now()
);

alter table notifications enable row level security;

create policy "Users see own notifications" on notifications
  for select using (auth.uid() = user_id);
create policy "Users update own notifications" on notifications
  for update using (auth.uid() = user_id);

alter publication supabase_realtime add table notifications;
alter table notifications replica identity full;

-- ২. নতুন অর্ডার এলে vendor কে notify করা
create or replace function notify_vendor_new_order()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into notifications (user_id, title, body, order_id)
  values (
    new.vendor_id,
    'নতুন অর্ডার এসেছে!',
    coalesce(new.product_name, 'একটি প্রোডাক্ট') || ' - ' || coalesce(new.quantity::text, '1') || ' পিস অর্ডার হয়েছে।',
    new.id
  );
  return new;
end;
$$;

create trigger trg_notify_vendor_new_order
after insert on orders
for each row execute function notify_vendor_new_order();

-- ৩. অর্ডার স্ট্যাটাস/পেমেন্ট স্ট্যাটাস বদলালে customer কে notify করা
create or replace function notify_buyer_status_change()
returns trigger
language plpgsql
security definer
as $$
begin
  if new.status is distinct from old.status then
    insert into notifications (user_id, title, body, order_id)
    values (
      new.user_id,
      'অর্ডার স্ট্যাটাস আপডেট',
      coalesce(new.product_name, 'আপনার প্রোডাক্ট') || ' এর স্ট্যাটাস এখন: ' || upper(new.status),
      new.id
    );
  end if;

  if new.payment_status is distinct from old.payment_status and new.payment_status = 'verified' then
    insert into notifications (user_id, title, body, order_id)
    values (
      new.user_id,
      'পেমেন্ট ভেরিফাই হয়েছে',
      coalesce(new.product_name, 'আপনার প্রোডাক্ট') || ' এর পেমেন্ট verify হয়েছে।',
      new.id
    );
  end if;

  return new;
end;
$$;

create trigger trg_notify_buyer_status_change
after update on orders
for each row execute function notify_buyer_status_change();
```

এই SQL চালানোর পর, `orders` table এ insert/update হলেই automatically
notification তৈরি হবে — Flutter কোডে আলাদা করে কিছু করতে হয় না।

### ভবিষ্যতে যদি Push Notification চান
Firebase project বানিয়ে (`flutterfire configure` দিয়ে) `firebase_messaging`
package যোগ করতে হবে, আর উপরের SQL trigger-এর ভেতরেই একটা
`http` extension call বা Supabase Edge Function দিয়ে FCM-এ পাঠাতে হবে। এটা
একটা আলাদা বড় কাজ — চাইলে পরে করে দিতে পারি।

---



### সমস্যা কী ছিল
Home page-এ (vendor আর user দুটোতেই) সব product একবারে `.stream()` দিয়ে লোড হতো —
মানে ৫টা product থাকুক বা ৫০০টা, সবগুলো একসাথে ডাউনলোড হয়ে আসতো। Product
সংখ্যা বাড়লে app স্লো হয়ে যেত।

### কী করা হলো
- `home_page.dart` (vendor) ও `user_home_page.dart` (user) — এখন product
  **১২টা করে page-wise** লোড হয় (`.range()` দিয়ে)
- নিচের দিকে scroll করলে automatic আরও ১২টা লোড হবে (infinite scroll) —
  scroll ৩০০px বাকি থাকতেই পরের page fetch শুরু হয়ে যায়, তাই user টের পায় না
- Category select করলে বা search করলে (400ms debounce সহ, টাইপ করার সাথে
  সাথেই বারবার query না গিয়ে থামার পর একবার query যায়) নতুন করে page ১
  থেকে fetch হয়
- Product list-এর নিচে দেখাবে "আর কোনো প্রোডাক্ট নেই" যখন সব লোড হয়ে যাবে

### Trade-off (জেনে রাখা ভালো)
Product list আর সত্যিকার realtime না — মানে কোনো নতুন product vendor
পোস্ট করলে সেটা home page-এ আগের মতো *সাথে সাথে* দেখাবে না, pull-to-refresh
করলে বা page আবার open করলে দেখাবে। এটা ইচ্ছাকৃত — একটা বড় product
catalog-এর জন্য pagination আর realtime একসাথে ঠিকভাবে করা জটিল, আর
product catalog সাধারণত cart/order-এর মতো live-critical না। Cart, Order,
Wishlist এখনো পুরোপুরি realtime আছে, শুধু product browsing pagination-based।

### Pull-to-Refresh
`cart_page.dart`, `order_page.dart`, `wishlist_page.dart`,
`vendor_orders_page.dart` — সব জায়গায় নিচের দিক থেকে টেনে (pull down)
refresh করার gesture যোগ হয়েছে। Cart/Order/Wishlist আগে থেকেই realtime
থাকায় ওখানে refresh শুধু ছোট্ট animation দেখায়; `vendor_orders_page.dart`
তে refresh করলে সত্যিকার নতুন করে ডাটা fetch হয়।

### করণীয়
কোনো নতুন package বা Supabase change লাগবে না — শুধু কোড আপডেট। App
rebuild করলেই কাজ করবে।

---

## Image Caching (Professional polish)

সব জায়গার `Image.network` কে `CachedNetworkImage` (package: `cached_network_image`)
দিয়ে replace করা হয়েছে — banner, product card, cart, orders, wishlist,
product details, vendor product details, vendor orders, my products — মোট ৯টা
ফাইলে। শুধু `vendor_dashboard.dart`-এ যেখানে picked local image (blob URL,
upload-এর আগে preview) দেখানো হয়, সেটা ইচ্ছাকৃতভাবে বাদ রাখা হয়েছে —
সেটা remote image না, caching এ কাজ হবে না।

### লাভ কী হলো
- একই image বারবার scroll/navigate করলে internet থেকে আবার download হবে না —
  disk cache থেকে সাথে সাথে দেখাবে
- ধীরগতির internet এও app আগের চেয়ে অনেক smooth লাগবে
- Loading এর সময় blank white বদলে একটা subtle placeholder দেখাবে,
  error হলে broken-image icon দেখাবে (আগের মতোই)

### করণীয়
`pubspec.yaml`-এ `cached_network_image: ^3.4.1` যোগ করা হয়েছে। শুধু project
এ terminal খুলে চালান:
```
flutter pub get
```
এটা ছাড়া আর কিছু করতে হবে না — কোনো Supabase/DB change লাগে না।

---



`wishlist_page.dart` এর `WishlistToggleButton` আগে ছিল one-time check (page
load হওয়ার সময় একবার চেক করতো item wishlist এ আছে কিনা)। এখন সেটা
`StreamBuilder` দিয়ে করা — মানে যেকোনো device/session থেকে wishlist এ item
add/remove হলে heart icon এবং `WishlistPage`-এর লিস্ট দুটোই সাথে সাথে
আপডেট হবে, কোনো manual refresh লাগবে না।

### এটা কাজ করার জন্য যা করতে হবে (Supabase dashboard এ):

Realtime by default off থাকে নতুন টেবিলে — on করে দিন:

```sql
alter publication supabase_realtime add table wishlist;
```

অথবা UI দিয়ে: **Database → Replication** → `supabase_realtime` এর নিচে
`wishlist` টেবিলের toggle ON করুন।

### আগে থেকে যা যা লাগবে (আগের round এ বলা হয়েছিল, রিমাইন্ডার হিসেবে):

```sql
-- Wishlist table
create table wishlist (
  id bigint generated by default as identity primary key,
  user_id uuid not null references auth.users(id),
  product_id bigint not null,
  product_name text,
  price numeric,
  image_url text,
  created_at timestamptz default now()
);
alter table wishlist enable row level security;
create policy "Users manage own wishlist" on wishlist
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Shipping address
alter table profiles add column phone text;
alter table profiles add column address text;
alter table orders add column shipping_address text;
alter table orders add column shipping_phone text;
```

### পারফরম্যান্স নোট
প্রতিটা product card তার নিজের `WishlistToggleButton` এর ভেতরে আলাদা করে
wishlist স্ট্রিম subscribe করে (user এর wishlist filtered by user_id)। এতে
Grid এ অনেক (৫০+) প্রোডাক্ট একসাথে থাকলে অনেকগুলো ছোট realtime subscription
তৈরি হবে — সাধারণ ব্যবহারে (২০-৩০ প্রোডাক্ট) এটা কোনো সমস্যা করবে না, কিন্তু
প্রোডাক্ট সংখ্যা অনেক বেশি হলে ভবিষ্যতে এটা একবার parent widget-এ lift করে
নিচে pass করা যেতে পারে optimization হিসেবে।
