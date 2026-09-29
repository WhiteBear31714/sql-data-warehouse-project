-- Transform & Load into silver.erp_cust_az12

PRINT '>> Truncating Table: silver.erp_cust_az12';
TRUNCATE TABLE silver.erp_cust_az12;
PRINT '>> Inserting Data Into: silver.erp_cust_az12'

INSERT INTO silver.erp_cust_az12(
	cid,
	bdate,
	gen
)

SELECT
	CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, len(cid))-- ตัด NAS
		 ELSE cid
	END AS cid,
-- ใช้ TRY_CAST หรือ TRY_CONVERT เพื่อป้องกัน Error Out-of-range
    CASE 
        WHEN TRY_CAST(bdate AS DATE) > GETDATE() THEN NULL -- ถ้าเป็นวันที่ในอนาคต เปลี่ยนเป็น NULL
        ELSE TRY_CAST(bdate AS DATE) -- ถ้าแปลงผ่านและไม่อยู่ในอนาคต ใช้ค่านั้น
    END AS bdate,-- Set future birthdates to NULL
	CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		 ELSE 'n/a'
	END AS gen -- Noemalize gender values and handle unknown cases
FROM bronze.erp_cust_az12

