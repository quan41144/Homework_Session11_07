begin;
-- Bước 1: Cũng kiểm tra số lượng vé (cùng thời điểm với User A)
select so_luong_con from ve_phim
where suat_chieu_id = 'SC003';
-- Bước 2: User B quyết định mua ngay lập tức
update ve_phim set so_luong_con = so_luong_con - 1
where suat_chieu_id = 'SC003' and so_luong_con > 0;
commit;