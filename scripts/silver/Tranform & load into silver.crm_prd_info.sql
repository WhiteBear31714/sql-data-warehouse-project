-- Transform & Load into silver.crm_prd_info

PRINT '>> Truncating Table: silver.crm_prd_info';
TRUNCATE TABLE silver.crm_prd_info;
PRINT '>> Inserting Data Into: silver.crm_prd_info'

INSERT INTO silver.crm_prd_info (
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
)

SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1 , 5), '-', '_') AS cat_id,-- "REPLACE ค้นหาและแทนที่ข้อความ '-', '_'"
	SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,-- "SUBSTRING ตัดข้อความ" / prd_key, 7 ให้เริ่มตั้งแต่ตัวที่ 7 / LEN(prd_key) ความยาวรวมทั้งหมดของข้อความนั้น
	prd_nm,
	ISNULL (prd_cost, 0) AS prd_cost,-- แทน n/a เป็น 0 
	CASE UPPER(TRIM(prd_line))
		WHEN 'M' THEN 'Mountain'
		WHEN 'R' THEN 'Road'
		WHEN 'S' THEN 'Other Sales'
		WHEN 'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,
	CAST (prd_start_dt AS DATE) AS prd_start_dt,-- "CAST(... AS DATE) แปลง string วันที่ เป็น DATE"
	-- ERROR: CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
	DATEADD(day, -1, CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) AS DATE)) AS prd_end_dt-- DATEADD(day, -1, ...) นำวันที่ของล็อตถัดไปมา ลบออก 1 วัน เพื่อให้เป็นวันจบของล็อตปัจจุบัน (ป้องกันช่วงเวลาทับซ้อนกัน)

FROM bronze.crm_prd_info

