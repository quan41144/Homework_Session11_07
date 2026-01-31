-- Cửa sổ 1 (User A)
/*begin;
-- Bước 1: Kiểm tra số lượng vé
select so_luong_con from ve_phim
where suat_chieu_id = 'SC003';
select * from ve_phim;
-- Bước 2: Giả sử User A quyết định mua, nhưng chưa UPDATE ngay
select pg_sleep(10);
-- Bước 3: Trừ vé
update ve_phim set so_luong_con = so_luong_con - 1
where suat_chieu_id = 'SC003' and so_luong_con > 0;
commit;
select * from ve_phim;*/

-- Sử dụng isolation Level repeatable read
begin;
set transaction isolation level repeatable read;
select so_luong_con from ve_phim where suat_chieu_id = 'SC003';
select pg_sleep(10);
update ve_phim set so_luong_con = so_luong_con - 1
where suat_chieu_id = 'SC003' and so_luong_con > 0;
commit;