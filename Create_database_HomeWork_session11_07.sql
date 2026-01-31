CREATE DATABASE pg_bank;
-- Bảng tài khoản ngân hàng

CREATE TABLE tai_khoan (
    id VARCHAR(10) PRIMARY KEY,
    ten_tai_khoan VARCHAR(100) NOT NULL,
    so_du DECIMAL(15,2) NOT NULL DEFAULT 0,
    trang_thai VARCHAR(20) DEFAULT 'ACTIVE',
    ngay_tao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Bảng giao dịch
CREATE TABLE giao_dich (
    id SERIAL PRIMARY KEY,
    tai_khoan_nguoi_gui VARCHAR(10),
    tai_khoan_nguoi_nhan VARCHAR(10),
    so_tien DECIMAL(15,2),
    loai_giao_dich VARCHAR(50),
    thoi_gian TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    trang_thai VARCHAR(20),
    mo_ta TEXT
);
-- Bảng vé xem phim (cho phần Isolation Levels)
CREATE TABLE ve_phim (
    id SERIAL PRIMARY KEY,
    suat_chieu_id VARCHAR(10),
    ten_phim VARCHAR(100),
    so_luong_con INT NOT NULL,
    gia_ve DECIMAL(10,2),
    ngay_chieu DATE
);
-- Thêm dữ liệu tài khoản
INSERT INTO tai_khoan (id, ten_tai_khoan, so_du, trang_thai) VALUES 
('TK001', 'Nguyen Van A', 5000000, 'ACTIVE'),
('TK002', 'Tran Thi B', 3000000, 'ACTIVE'),
('TK003', 'Le Van C', 1000000, 'LOCKED'),
('TK004', 'Pham Thi D', 2000000, 'ACTIVE'),
('TK005', 'Bank Fee Account', 0, 'ACTIVE');
-- Thêm dữ liệu vé phim
INSERT INTO ve_phim (suat_chieu_id, ten_phim, so_luong_con, gia_ve, ngay_chieu) VALUES 
('SC001', 'Avengers: Endgame', 5, 80000, '2024-01-15'),
('SC002', 'Spider-Man: No Way Home', 3, 75000, '2024-01-16'),
('SC003', 'The Batman', 1, 85000, '2024-01-17');  -- Chỉ còn 1 vé!

-- PHẦN 1: TRANSACTION CƠ BẢN - CHUYỂN KHOẢN NGÂN HÀNG 
/*Bài 1.1: Vấn đề không dùng Transaction
Tình huống: Chuyển 1.000.000đ từ TK001 sang TK002*/
select * from tai_khoan;
-- 1. Chạy các lệnh trên và quan sát kết quả
-- Code có vấn đề (KHÔNG an toàn):
UPDATE tai_khoan SET so_du = so_du - 1000000 WHERE id = 'TK001';
-- Giả sử dòng này bị lỗi syntax hoặc mất điện
UPDAT tai_khoan SET so_du = so_du + 1000000 WHERE id = 'TK002';  -- Lỗi cố ý
-- 2. Kiểm tra số dư TK001 và TK002 sau khi chạy
select * from tai_khoan;
-- 3. Giải thích vấn đề xảy ra và tại sao đây là vấn đề "sống còn" trong ngân hàng?
/*Vấn đề xảy ra: TK001 bị trừ tiền, trong khi TK002 không được cộng vào, số tiền bị mất.
Đây là vấn đề rất nghiêm trọng trong ngân hàng, vì có thể vô tình thất thoát số tiền rất lớn.*/

/*Bài 1.2: Giải pháp với Transaction*/
-- Viết lại nghiệp vụ chuyển khoản sử dụng
create or replace procedure bank_transfer(
	p_id_01 varchar(10),
	p_id_02 varchar(10),
	p_money_transfer numeric(10,2)
)
language plpgsql
as $$
declare
	v_so_du_01 numeric;
	v_trang_thai_01 varchar;
	v_so_du_02 numeric;
	v_trang_thai_02 varchar;
begin
	-- Kiểm tra số dư
	select so_du, trang_thai into v_so_du_01, v_trang_thai_01 from tai_khoan where id = p_id_01;
	if not found then
		raise exception 'Tài khoản gửi không tồn tại!';
	end if;
	select so_du, trang_thai into v_so_du_02, v_trang_thai_02 from tai_khoan where id = p_id_02;
	if not found then
		raise exception 'Tài khoản nhận không tồn tại!';
	end if;
	if v_trang_thai_01 = 'LOCKED' then
		raise exception 'Tài khoản chuyển tiền đã bị khóa!';
	elsif v_trang_thai_02 = 'LOCKED' then
		raise exception 'Tài khoản nhận tiền đã bị khóa!';
	else
		if v_so_du_01 < p_money_transfer then
			raise exception 'Số dư không đủ!';
		else
			v_so_du_01 := v_so_du_01 - p_money_transfer;
			update tai_khoan set so_du = v_so_du_01 where id = p_id_01;
			v_so_du_02 := v_so_du_02 + p_money_transfer;
			update tai_khoan set so_du = v_so_du_02 where id = p_id_02;
			insert into giao_dich(tai_khoan_nguoi_gui, tai_khoan_nguoi_nhan, so_tien, loai_giao_dich, thoi_gian, trang_thai)
			values (p_id_01, p_id_02, p_money_transfer, 'CHUYEN TIEN', now(), 'THANH CONG');
		end if;
	end if;
	exception
		when others then
			rollback;
		raise exception 'Co loi he thong!';
end;
$$;

call bank_transfer('TK002', 'TK001', 1000000);
select * from tai_khoan;
select * from giao_dich;
-- Bài 2.2: Test các trường hợp thực tế
-- TH1: Chuyển thành công
call chuyen_khoan_an_toan('TK001', 'TK002', 500000);
-- TH2: Số dư không đủ
call chuyen_khoan_an_toan('TK001', 'TK002', 10000000);
-- TH3: Tài khoản bị khóa
call chuyen_khoan_an_toan('TK003', 'TK001', 100000);
-- TH4: Tài khoản không tồn tại
call chuyen_khoan_an_toan('TK999', 'TK001', 100000);
-- Kiểm tra dữ liệu sau mỗi lần test:
SELECT * FROM tai_khoan ORDER BY id;
SELECT * FROM giao_dich ORDER BY thoi_gian DESC;

-- PHẦN 3: ISOLATION LEVELS - BÀI TOÁN BÁN VÉ & CẠNH TRANH DỮ LIỆU 
-- Bài 3.1: Mô phỏng "Race Condition" trong bán vé
-- Chạy tuần tự theo hướng dẫn trên
-- Quan sát kết quả cuối cùng của so_luong_con
-- Giải thích hiện tượng xảy ra và cho biết đây là "hiện tượng lạ" nào?
/*Đây là hiện tượng Lost Update (Tranh chấp dữ liệu)*/

-- Bài 3.2: Giải quyết với Isolation Level phù hợp
update ve_phim set so_luong_con = 1 where suat_chieu_id = 'SC003';
select * from ve_phim;
-- Em chọn Isolation Level nào? Tại sao?
/*Em chọn repeatable read, vì nó không cho ghi đè dữ liệu*/
-- Giải thích sự khác biệt giữa READ COMMITTED và REPEATABLE READ trong tình huống này
/*Trong tình huống này,
Đối với read committed:
userA sẽ chờ userB commit, có thể bị non-repeatable read: Đọc lần 1 thấy vé, đọc lần 2 thì thấy 0 vé.
Đối với repeatable read:
userA sẽ dừng ngay lập tức nếu dữ liệu đã bị userB thay đổi,
đảm bảo đọc 10 lần vẫn thấy 1 vé (do sử dụng snapshot tại thời điểm bắt đầu)*/
-- Khi nào nên dùng SERIALIZABLE?
/*Khi:
Giao dịch cực kỳ phức tạp
Yêu cầu độ chính xác tuyệt đối
Chấp nhận rủi ro lỗi cao*/

-- PHẦN 4: XỬ LÝ LỖI PHỨC TẠP VỚI SAVEPOINT
-- Bài 4.1: Nghiệp vụ "CHUYỂN TIỀN VÀ MUA VÉ"
-- Viết procedure xử lý nghiệp vụ phức tạp này với SAVEPOINT
create or replace function chuyen_tien_va_mua_ve(
    p_tk_khach varchar(10),
    p_tk_thu_huong varchar(10),
    p_tk_phi varchar(10),
    p_suat_chieu varchar(10),
    p_so_luong_ve int
) 
returns varchar
language plpgsql
as $$
declare
    v_gia_ve decimal(15,2);
    v_tong_tien_ve decimal(15,2);
    v_phi_gd decimal(15,2) := 5000;
    v_so_du_khach decimal(15,2);
begin
    begin
        select so_du into v_so_du_khach from tai_khoan where id = p_tk_khach for update;
        if v_so_du_khach < v_phi_gd then
            return 'Không đủ tiền trả phí giao dịch.';
        end if;
        update tai_khoan set so_du = so_du - v_phi_gd where id = p_tk_khach;
        update tai_khoan set so_du = so_du + v_phi_gd where id = p_phi_gd;
        insert into giao_dich(tai_khoan_nguoi_gui, tai_khoan_nguoi_nhan, so_tien, loai_giao_dich, trang_thai, mo_ta)
        values (p_tk_khach, p_tk_phi, v_phi_gd, 'PHI GD', 'THANH CONG', 'Phí hệ thống');
    exception
		when others then
        return 'Lỗi hệ thống!';
    end;
    -- Chuyển tiền từ TK004 sang TK001 (1.000.000đ)
    begin
        select gia_ve into v_gia_ve from ve_phim where suat_chieu_id = p_suat_chieu for update;
        v_tong_tien_ve := v_gia_ve * p_so_luong_ve;
        select so_du into v_so_du_khach from tai_khoan where id = p_tk_khach;
        if v_so_du_khach < (1000000 + v_tong_tien_ve) then
            raise exception 'Không đủ số dư để chuyển khoản và mua vé.';
        end if;
        update tai_khoan set so_du = so_du - 1000000 where id = p_tk_khach;
        update tai_khoan set so_du = so_du + 1000000 where id = p_tk_thu_huong;
        update ve_phim 
        set so_luong_con = so_luong_con - p_so_luong_ve 
        where suat_chieu_id = p_suat_chieu and so_luong_con >= p_so_luong_ve;
        if not found then
            raise exception 'Hết vé cho suất chiếu này!';
        end if;
        -- Ghi log thành công
        insert into giao_dich(tai_khoan_nguoi_gui, tai_khoan_nguoi_nhan, so_tien, loai_giao_dich, trang_thai, mo_ta)
        values (p_tk_khach, p_tk_thu_huong, 1000000, 'CHUYEN TIEN', 'THANH CONG', 'Chuyển khoản mua vé');

        return 'Thành công: Đã thu phí, chuyển tiền và đặt vé.';

    exception when others then
        insert into giao_dich(tai_khoan_nguoi_gui, tai_khoan_nguoi_nhan, so_tien, loai_giao_dich, trang_thai)
        values (p_tk_khach, p_suat_chieu, 0, 'MUA VE', 'THAT BAI');
        return 'Thu phí thành công nhưng giao dịch không thành công';
    end;
end;
$$;
-- Bài 4.2: Test nghiệp vụ phức tạp
-- Chạy procedure và quan sát kết quả
-- Kiểm tra dữ liệu ở cả 3 bảng: tai_khoan, giao_dich, ve_phim
-- Thử tạo tình huống lỗi (ví dụ: không đủ vé) để kiểm tra rollback
-- Chạy procedure với số lượng vé không tưởng
select chuyen_tien_va_mua_ve('TK004', 'TK001', 'TK005', 'SC001', 10);
select * from tai_khoan where id in ('TK004', 'TK001', 'TK005');
select * from ve_phim where suat_chieu_id = 'SC001';
select * from giao_dich order by thoi_gian desc limit 2;